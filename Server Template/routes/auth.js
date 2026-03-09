const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const validator = require('validator');
const { pool } = require('../db/pool');
const { extractBearerToken } = require('../middleware/auth');

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

function signAccessToken(user) {
    const userId = user.id || user.userId;
    return jwt.sign({ userId, email: user.email }, JWT_SECRET, {
        expiresIn: '7d'
    });
}

// MARK: - Register
router.post('/register', async (req, res) => {
    try {
        const { email, password, displayName } = req.body;

        // Validation
        if (!email || !password || !displayName) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        if (!validator.isEmail(email)) {
            return res.status(400).json({ error: 'Invalid email address' });
        }

        if (password.length < 8) {
            return res.status(400).json({ error: 'Password must be at least 8 characters' });
        }

        const normalizedEmail = email.trim().toLowerCase();
        const trimmedDisplayName = displayName.trim();
        if (!trimmedDisplayName) {
            return res.status(400).json({ error: 'Display name is required' });
        }

        // Check if user already exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [normalizedEmail]
        );
        if (existingUser.rowCount > 0) {
            return res.status(409).json({ error: 'Email already registered' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user
        const insertResult = await pool.query(
            `INSERT INTO users (email, password_hash, display_name, last_sign_in_at)
             VALUES ($1, $2, $3, NOW())
             RETURNING id, email, display_name, created_at, last_sign_in_at, is_subscribed`,
            [normalizedEmail, hashedPassword, trimmedDisplayName]
        );
        const user = insertResult.rows[0];

        // Generate token
        const token = signAccessToken(user);

        res.status(201).json({
            user: {
                id: user.id,
                email: user.email,
                displayName: user.display_name,
                isSubscribed: user.is_subscribed,
                createdAt: user.created_at,
                lastSignInAt: user.last_sign_in_at
            },
            token
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // Validation
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password required' });
        }

        const normalizedEmail = email.trim().toLowerCase();

        // Find user
        const result = await pool.query(
            `SELECT id, email, password_hash, display_name, is_subscribed, created_at, last_sign_in_at
             FROM users
             WHERE email = $1`,
            [normalizedEmail]
        );
        if (result.rowCount === 0) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }
        const user = result.rows[0];

        // Verify password
        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        // Update last sign in
        const updatedUserResult = await pool.query(
            `UPDATE users
             SET last_sign_in_at = NOW(), updated_at = NOW()
             WHERE id = $1
             RETURNING last_sign_in_at`,
            [user.id]
        );

        // Generate token
        const token = signAccessToken(user);
        const lastSignInAt = updatedUserResult.rows[0]?.last_sign_in_at || user.last_sign_in_at;

        res.json({
            user: {
                id: user.id,
                email: user.email,
                displayName: user.display_name,
                isSubscribed: user.is_subscribed,
                createdAt: user.created_at,
                lastSignInAt
            },
            token
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Verify Token
router.post('/verify', async (req, res) => {
    try {
        const token = extractBearerToken(req.headers.authorization);

        if (!token) {
            return res.status(401).json({ error: 'No token provided' });
        }

        const decoded = jwt.verify(token, JWT_SECRET);
        const userCheck = await pool.query(
            'SELECT id FROM users WHERE id = $1',
            [decoded.userId]
        );
        if (userCheck.rowCount === 0) {
            return res.status(401).json({ error: 'Token user not found' });
        }

        res.json({ valid: true, userId: decoded.userId, email: decoded.email });
    } catch (error) {
        res.status(401).json({ error: 'Invalid token' });
    }
});

// MARK: - Refresh Token
router.post('/refresh', (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (!refreshToken) {
            return res.status(400).json({ error: 'Refresh token required' });
        }

        const decoded = jwt.verify(refreshToken, JWT_SECRET);
        const newToken = signAccessToken(decoded);

        res.json({ token: newToken });
    } catch (error) {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

module.exports = router;
