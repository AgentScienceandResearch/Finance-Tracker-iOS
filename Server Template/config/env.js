const DEV_FALLBACK_JWT_SECRET = 'dev-insecure-jwt-secret-change-me';
const INVALID_PROD_JWT_SECRETS = new Set([
    '',
    'replace_with_a_long_random_secret',
    'your-secret-key-change-in-production',
    DEV_FALLBACK_JWT_SECRET
]);

function getJWTSecret() {
    return process.env.JWT_SECRET || DEV_FALLBACK_JWT_SECRET;
}

function getClaudeConfig() {
    return {
        apiKey: process.env.ANTHROPIC_API_KEY || '',
        model: process.env.CLAUDE_MODEL || 'claude-haiku-4-5'
    };
}

function getServerConfig() {
    const nodeEnv = process.env.NODE_ENV || 'development';
    const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000')
        .split(',')
        .map(origin => origin.trim())
        .filter(Boolean);

    return {
        nodeEnv,
        isProduction: nodeEnv === 'production',
        port: Number(process.env.PORT || 8000),
        rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 100),
        allowedOrigins,
        databaseURL: process.env.DATABASE_URL || '',
        jwtSecret: getJWTSecret(),
        claude: getClaudeConfig(),
        logoDevToken: process.env.LOGO_DEV_TOKEN || ''
    };
}

function validateServerEnv() {
    const config = getServerConfig();
    const missing = [];

    if (config.isProduction) {
        if (config.allowedOrigins.length === 0) {
            missing.push('ALLOWED_ORIGINS');
        }

        if (!config.claude.apiKey) {
            missing.push('ANTHROPIC_API_KEY');
        }

        if (INVALID_PROD_JWT_SECRETS.has(config.jwtSecret)) {
            missing.push('JWT_SECRET');
        }
    }

    if (missing.length > 0) {
        throw new Error(`Missing or invalid required environment variables: ${missing.join(', ')}`);
    }

    return config;
}

module.exports = {
    getJWTSecret,
    getClaudeConfig,
    getServerConfig,
    validateServerEnv
};
