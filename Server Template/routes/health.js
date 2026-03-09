const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');

// MARK: - Health Check
router.get('/', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// MARK: - Database Health Check
router.get('/db', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW() as now');

        res.json({
            status: 'ok',
            database: 'connected',
            databaseTime: result.rows[0]?.now,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            status: 'error',
            database: 'disconnected',
            error: error.message
        });
    }
});

module.exports = router;
