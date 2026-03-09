const express = require('express');
const router = express.Router();
const validator = require('validator');
const { pool } = require('../db/pool');
const { verifyToken } = require('../middleware/auth');

// MARK: - Get User Profile
router.get('/profile', verifyToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, email, display_name, profile_image_url, created_at, last_sign_in_at, is_subscribed
             FROM users
             WHERE id = $1`,
            [req.userId]
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        const user = result.rows[0];

        res.json({
            id: user.id,
            email: user.email,
            displayName: user.display_name,
            profileImageUrl: user.profile_image_url,
            createdAt: user.created_at,
            lastSignInAt: user.last_sign_in_at,
            isSubscribed: user.is_subscribed
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Update User Profile
router.put('/profile', verifyToken, async (req, res) => {
    try {
        const { displayName, profileImageUrl } = req.body;
        if (displayName === undefined && profileImageUrl === undefined) {
            return res.status(400).json({ error: 'No fields provided to update' });
        }

        const updates = [];
        const values = [];
        let nextIndex = 1;

        if (displayName !== undefined) {
            if (typeof displayName !== 'string' || !displayName.trim()) {
                return res.status(400).json({ error: 'Display name must be a non-empty string' });
            }
            updates.push(`display_name = $${nextIndex}`);
            values.push(displayName.trim());
            nextIndex += 1;
        }

        if (profileImageUrl !== undefined) {
            if (profileImageUrl !== null && profileImageUrl !== '' &&
                (typeof profileImageUrl !== 'string' ||
                    !validator.isURL(profileImageUrl, { require_protocol: true }))) {
                return res.status(400).json({ error: 'Profile image URL must be a valid URL' });
            }
            updates.push(`profile_image_url = $${nextIndex}`);
            values.push(profileImageUrl || null);
            nextIndex += 1;
        }

        values.push(req.userId);
        const result = await pool.query(
            `UPDATE users
             SET ${updates.join(', ')}, updated_at = NOW()
             WHERE id = $${nextIndex}
             RETURNING id, email, display_name, profile_image_url`,
            values
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        const user = result.rows[0];

        res.json({
            id: user.id,
            email: user.email,
            displayName: user.display_name,
            profileImageUrl: user.profile_image_url
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Delete User
router.delete('/profile', verifyToken, async (req, res) => {
    try {
        const result = await pool.query(
            'DELETE FROM users WHERE id = $1 RETURNING id',
            [req.userId]
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// MARK: - Get User Stats
router.get('/stats', verifyToken, async (req, res) => {
    try {
        const userResult = await pool.query(
            'SELECT id, created_at, last_sign_in_at, is_subscribed FROM users WHERE id = $1',
            [req.userId]
        );
        if (userResult.rowCount === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        const user = userResult.rows[0];

        const subscriptionResult = await pool.query(
            `SELECT
                COUNT(*)::int AS total_subscriptions,
                COUNT(*) FILTER (WHERE status = 'active' AND is_active = TRUE)::int AS active_subscriptions
             FROM subscriptions
             WHERE user_id = $1`,
            [req.userId]
        );
        const subscriptionStats = subscriptionResult.rows[0];

        res.json({
            userId: user.id,
            createdAt: user.created_at,
            lastSignInAt: user.last_sign_in_at,
            isSubscribed: user.is_subscribed,
            subscriptions: {
                total: subscriptionStats.total_subscriptions,
                active: subscriptionStats.active_subscriptions
            },
            preferences: {
                darkMode: false,
                notifications: false,
                language: 'en'
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
