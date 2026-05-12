const express = require('express');
const router = express.Router();
const validator = require('validator');
const { pool } = require('../db/pool');
const { verifyToken } = require('../middleware/auth');

const plans = [
    {
        id: 'weekly',
        name: 'Weekly',
        price: 2.99,
        currency: 'USD',
        interval: 'week',
        intervalDays: 7,
        description: 'Weekly access to premium features'
    },
    {
        id: 'monthly',
        name: 'Monthly',
        price: 9.99,
        currency: 'USD',
        interval: 'month',
        intervalDays: 30,
        description: 'Monthly access to premium features',
        popular: true
    },
    {
        id: 'yearly',
        name: 'Yearly',
        price: 79.99,
        currency: 'USD',
        interval: 'year',
        intervalDays: 365,
        description: 'Yearly access at 34% discount',
        savings: '2 months free'
    }
];

function mapSubscriptionRowToResponse(subscription) {
    return {
        id: subscription.id,
        userId: subscription.user_id,
        planId: subscription.plan_id,
        transactionId: subscription.transaction_id,
        provider: subscription.provider,
        providerSubscriptionId: subscription.provider_subscription_id,
        status: subscription.status,
        isSubscribed: subscription.is_active,
        autoRenew: subscription.auto_renew,
        currentPeriodStart: subscription.current_period_start,
        expiryDate: subscription.current_period_end,
        renewalDate: subscription.current_period_end,
        cancelledAt: subscription.cancelled_at,
        createdAt: subscription.created_at,
        updatedAt: subscription.updated_at
    };
}

// MARK: - Get Subscription Status
router.get('/status', verifyToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, user_id, plan_id, transaction_id, provider, provider_subscription_id, status,
                    is_active, auto_renew, current_period_start, current_period_end, cancelled_at,
                    created_at, updated_at
             FROM subscriptions
             WHERE user_id = $1
             ORDER BY created_at DESC
             LIMIT 1`,
            [req.userId]
        );

        if (result.rowCount === 0) {
            return res.json({
                isSubscribed: false,
                planId: null,
                expiryDate: null
            });
        }
        const subscription = result.rows[0];

        res.json(mapSubscriptionRowToResponse(subscription));
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Create Subscription
router.post('/', verifyToken, async (req, res) => {
    try {
        const { planId, transactionId, provider, providerSubscriptionId, metadata } = req.body;

        if (!planId) {
            return res.status(400).json({ error: 'Plan ID required' });
        }

        const plan = plans.find(item => item.id === planId);
        if (!plan) {
            return res.status(400).json({ error: 'Invalid plan ID' });
        }

        const now = new Date();
        const expiryDate = new Date(now.getTime() + plan.intervalDays * 24 * 60 * 60 * 1000);

        await pool.query('BEGIN');
        let subscription;
        try {
            const insertResult = await pool.query(
                `INSERT INTO subscriptions (
                    user_id,
                    provider,
                    provider_subscription_id,
                    plan_id,
                    transaction_id,
                    status,
                    is_active,
                    auto_renew,
                    current_period_start,
                    current_period_end,
                    metadata
                )
                VALUES ($1, $2, $3, $4, $5, 'active', TRUE, TRUE, NOW(), $6, $7::jsonb)
                RETURNING id, user_id, plan_id, transaction_id, provider, provider_subscription_id, status,
                          is_active, auto_renew, current_period_start, current_period_end, cancelled_at,
                          created_at, updated_at`,
                [
                    req.userId,
                    provider || 'app_store',
                    providerSubscriptionId || null,
                    planId,
                    transactionId || null,
                    expiryDate,
                    JSON.stringify(metadata || {})
                ]
            );
            subscription = insertResult.rows[0];

            await pool.query(
                'UPDATE users SET is_subscribed = TRUE, updated_at = NOW() WHERE id = $1',
                [req.userId]
            );

            await pool.query('COMMIT');
        } catch (innerError) {
            await pool.query('ROLLBACK');
            throw innerError;
        }

        res.status(201).json({
            message: 'Subscription created successfully',
            subscription: mapSubscriptionRowToResponse(subscription)
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Cancel Subscription
router.delete('/:subscriptionId', verifyToken, async (req, res) => {
    try {
        const { subscriptionId } = req.params;
        if (!validator.isUUID(subscriptionId)) {
            return res.status(400).json({ error: 'Invalid subscription ID' });
        }

        await pool.query('BEGIN');
        let subscription;
        try {
            const updateResult = await pool.query(
                `UPDATE subscriptions
                 SET is_active = FALSE,
                     status = 'cancelled',
                     auto_renew = FALSE,
                     cancelled_at = NOW(),
                     updated_at = NOW()
                 WHERE id = $1 AND user_id = $2
                 RETURNING id, user_id, plan_id, transaction_id, provider, provider_subscription_id, status,
                           is_active, auto_renew, current_period_start, current_period_end, cancelled_at,
                           created_at, updated_at`,
                [subscriptionId, req.userId]
            );
            if (updateResult.rowCount === 0) {
                await pool.query('ROLLBACK');
                return res.status(404).json({ error: 'Subscription not found' });
            }
            subscription = updateResult.rows[0];

            const activeCheck = await pool.query(
                `SELECT EXISTS(
                    SELECT 1
                    FROM subscriptions
                    WHERE user_id = $1
                      AND is_active = TRUE
                      AND (current_period_end IS NULL OR current_period_end > NOW())
                ) AS has_active_subscription`,
                [req.userId]
            );

            await pool.query(
                'UPDATE users SET is_subscribed = $2, updated_at = NOW() WHERE id = $1',
                [req.userId, activeCheck.rows[0].has_active_subscription]
            );

            await pool.query('COMMIT');
        } catch (innerError) {
            await pool.query('ROLLBACK');
            throw innerError;
        }

        res.json({
            message: 'Subscription cancelled successfully',
            subscription: mapSubscriptionRowToResponse(subscription)
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Get Available Plans
router.get('/plans/available', (req, res) => {
    try {
        res.json(plans.map(({ intervalDays, ...plan }) => plan));
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Validate Receipt
router.post('/validate-receipt', verifyToken, (req, res) => {
    try {
        const { receipt } = req.body;

        if (!receipt) {
            return res.status(400).json({ error: 'Receipt required' });
        }

        // In production, validate with Apple/Stripe and persist subscription updates.
        res.status(501).json({
            error: 'Receipt validation is not implemented yet'
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
