require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { pool } = require('./db/pool');
const { getServerConfig, validateServerEnv } = require('./config/env');

const serverConfig = getServerConfig();
try {
    validateServerEnv();
} catch (error) {
    const strictValidation = process.env.STRICT_ENV_VALIDATION === 'true';
    if (strictValidation) {
        throw error;
    }

    console.warn(`Environment validation warning (non-fatal): ${error.message}`);
}

// Initialize Express app
const app = express();

// Middleware
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({
    origin: serverConfig.allowedOrigins,
    credentials: true
}));
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: serverConfig.rateLimitMax,
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

module.exports = app;

function startServer() {
    const port = serverConfig.port;
    const server = app.listen(port, async () => {
        console.log(`Server running on port ${port}`);

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
}

if (require.main === module) {
    startServer();
}
