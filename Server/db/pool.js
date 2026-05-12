const { Pool } = require('pg');

const hasDatabaseURL = Boolean(process.env.DATABASE_URL);
const isProduction = process.env.NODE_ENV === 'production';

const baseConfig = hasDatabaseURL
    ? {
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.DATABASE_SSL === 'false'
            ? false
            : (isProduction ? { rejectUnauthorized: false } : false)
    }
    : {
        user: process.env.DB_USER || 'postgres',
        host: process.env.DB_HOST || 'localhost',
        database: process.env.DB_NAME || 'app_template_db',
        password: process.env.DB_PASSWORD,
        port: Number(process.env.DB_PORT || 5432),
        ssl: process.env.DATABASE_SSL === 'true'
            ? { rejectUnauthorized: false }
            : false
    };

const pool = new Pool(baseConfig);

module.exports = {
    pool
};
