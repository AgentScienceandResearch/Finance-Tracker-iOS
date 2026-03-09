require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { pool } = require('./db/pool');

// Initialize Express app
const app = express();
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000')
    .split(',')
    .map(origin => origin.trim())
    .filter(Boolean);

// Middleware
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({
    origin: allowedOrigins,
    credentials: true
}));
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: Number(process.env.RATE_LIMIT_MAX || 100),
    message: 'Too many requests, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
});

app.use('/api/', limiter);

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/subscriptions', require('./routes/subscriptions'));
app.use('/api/finance', require('./routes/finance'));
app.use('/api/health', require('./routes/health'));

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(err.status || 500).json({
        error: err.message,
        status: err.status || 500
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Start server
const PORT = process.env.PORT || 8000;
const server = app.listen(PORT, async () => {
    console.log(`Server running on port ${PORT}`);

    try {
        await pool.query('SELECT NOW()');
        console.log('Database connection check succeeded');
    } catch (error) {
        console.error('Database connection check failed:', error.message);
    }
});

const shutdown = async () => {
    try {
        await pool.end();
    } catch (_) {
        // Ignore pool close errors on shutdown
    } finally {
        server.close(() => process.exit(0));
    }
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = app;
