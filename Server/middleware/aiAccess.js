const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const {
    SignedDataVerifier,
    Environment,
    VerificationException,
    VerificationStatus
} = require('@apple/app-store-server-library');
const { pool } = require('../db/pool');
const { getAIAccessConfig } = require('../config/env');

// Pro access is granted only by an Apple-signed subscription transaction for
// one of these products. Everything else falls back to the free allowance.
const PRO_PRODUCT_IDS = new Set([
    'com.agentscienceandresearch.financetrackerios.monthly',
    'com.agentscienceandresearch.financetrackerios.yearly'
]);

const DEVICE_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ENTITLEMENT_CACHE_MS = 10 * 60 * 1000;

// ─── Entitlement verification ────────────────────────────────────────────────

let verifiers = null;

function loadVerifiers() {
    if (verifiers) return verifiers;

    const config = getAIAccessConfig();
    const certDir = path.join(__dirname, '..', 'certs');
    const roots = fs.readdirSync(certDir)
        .filter(name => name.endsWith('.cer'))
        .map(name => fs.readFileSync(path.join(certDir, name)));

    verifiers = {
        production: new SignedDataVerifier(roots, true, Environment.PRODUCTION, config.bundleId, config.appAppleId),
        // TestFlight and App Review purchase in the sandbox.
        sandbox: new SignedDataVerifier(roots, true, Environment.SANDBOX, config.bundleId)
    };
    return verifiers;
}

const entitlementCache = new Map();

async function decodeTransaction(jws) {
    const { production, sandbox } = loadVerifiers();
    try {
        return await production.verifyAndDecodeTransaction(jws);
    } catch (error) {
        if (error instanceof VerificationException && error.status === VerificationStatus.INVALID_ENVIRONMENT) {
            return sandbox.verifyAndDecodeTransaction(jws);
        }
        throw error;
    }
}

async function hasActiveEntitlement(jws, now = Date.now()) {
    const key = crypto.createHash('sha256').update(jws).digest('hex');
    const cached = entitlementCache.get(key);
    if (cached && cached.checkUntil > now) {
        return cached.expiresAt > now;
    }

    let transaction;
    try {
        transaction = await decodeTransaction(jws);
    } catch (error) {
        console.warn(`App Store transaction rejected: ${error.status ?? error.message}`);
        return false;
    }

    const expiresAt = Number(transaction.expiresDate || 0);
    const active = PRO_PRODUCT_IDS.has(transaction.productId)
        && !transaction.revocationDate
        && expiresAt > now;

    entitlementCache.set(key, {
        expiresAt: active ? expiresAt : 0,
        checkUntil: now + ENTITLEMENT_CACHE_MS
    });
    if (entitlementCache.size > 10_000) {
        entitlementCache.delete(entitlementCache.keys().next().value);
    }

    return active;
}

// ─── Free usage allowance ────────────────────────────────────────────────────

const memoryUsage = new Map();
let usageTableReady = null;

function currentPeriod(now = new Date()) {
    return now.toISOString().slice(0, 7); // YYYY-MM, UTC
}

function ensureUsageTable() {
    if (!usageTableReady) {
        usageTableReady = pool.query(`
            CREATE TABLE IF NOT EXISTS ai_usage (
                device_id TEXT NOT NULL,
                period TEXT NOT NULL,
                count INTEGER NOT NULL DEFAULT 0,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                PRIMARY KEY (device_id, period)
            )
        `).catch(error => {
            usageTableReady = null;
            throw error;
        });
    }
    return usageTableReady;
}

// Atomically reserves one use. Returns the count after reserving, or null when
// the device has already reached the limit.
async function reserveUse(deviceId, limit) {
    const period = currentPeriod();
    try {
        await ensureUsageTable();
        const result = await pool.query(
            `INSERT INTO ai_usage (device_id, period, count)
             VALUES ($1, $2, 1)
             ON CONFLICT (device_id, period)
             DO UPDATE SET count = ai_usage.count + 1, updated_at = NOW()
             WHERE ai_usage.count < $3
             RETURNING count`,
            [deviceId, period, limit]
        );
        return result.rowCount === 0 ? null : result.rows[0].count;
    } catch (error) {
        console.warn(`AI usage store unavailable, using memory: ${error.message}`);
        const key = `${deviceId}:${period}`;
        const used = memoryUsage.get(key) || 0;
        if (used >= limit) return null;
        memoryUsage.set(key, used + 1);
        return used + 1;
    }
}

async function refundUse(deviceId) {
    const period = currentPeriod();
    try {
        await pool.query(
            `UPDATE ai_usage SET count = GREATEST(count - 1, 0), updated_at = NOW()
             WHERE device_id = $1 AND period = $2`,
            [deviceId, period]
        );
    } catch (_) {
        const key = `${deviceId}:${period}`;
        const used = memoryUsage.get(key) || 0;
        if (used > 0) memoryUsage.set(key, used - 1);
    }
}

// ─── Middleware ──────────────────────────────────────────────────────────────

function subscriptionRequired(res, limit) {
    res.set('X-AI-Plan', 'free');
    res.set('X-AI-Free-Limit', String(limit));
    res.set('X-AI-Free-Remaining', '0');
    return res.status(402).json({
        error: 'Upgrade to Finance Tracker Pro to keep using AI.',
        code: 'subscription_required'
    });
}

/**
 * Gates an AI route on an App Store subscription.
 * - proOnly routes require an active subscription.
 * - Other routes allow a small monthly allowance per device for free users.
 * Clients older than 4.3.0 send neither header and are governed by
 * LEGACY_AI_ACCESS so existing installs keep working until it is switched off.
 */
function requireAIAccess({ proOnly = false } = {}) {
    return async (req, res, next) => {
        const config = getAIAccessConfig();
        const transactionJWS = req.get('x-app-store-transaction');
        const deviceId = req.get('x-device-id');

        if (transactionJWS && await hasActiveEntitlement(transactionJWS)) {
            res.set('X-AI-Plan', 'pro');
            return next();
        }

        if (!deviceId) {
            if (config.legacyAccess === 'allow') return next();
            return subscriptionRequired(res, config.freeMessagesPerMonth);
        }

        if (!DEVICE_ID_PATTERN.test(deviceId)) {
            return res.status(400).json({ error: 'Invalid device identifier.' });
        }

        const limit = config.freeMessagesPerMonth;
        if (proOnly || limit <= 0) {
            return subscriptionRequired(res, limit);
        }

        const used = await reserveUse(deviceId.toLowerCase(), limit);
        if (used === null) {
            return subscriptionRequired(res, limit);
        }

        // Failed AI calls do not consume the allowance.
        res.on('finish', () => {
            if (res.statusCode >= 400) refundUse(deviceId.toLowerCase());
        });

        res.set('X-AI-Plan', 'free');
        res.set('X-AI-Free-Limit', String(limit));
        res.set('X-AI-Free-Remaining', String(Math.max(limit - used, 0)));
        return next();
    };
}

function resetAIAccessStateForTests() {
    entitlementCache.clear();
    memoryUsage.clear();
    usageTableReady = null;
    verifiers = null;
}

module.exports = {
    requireAIAccess,
    hasActiveEntitlement,
    PRO_PRODUCT_IDS,
    resetAIAccessStateForTests
};
