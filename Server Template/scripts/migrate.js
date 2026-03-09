#!/usr/bin/env node
require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { pool } = require('../db/pool');

async function migrate() {
    const schemaPath = path.join(__dirname, '..', 'db', 'schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');

    await pool.query('BEGIN');
    try {
        await pool.query(sql);
        await pool.query('COMMIT');
        console.log('Database migration completed');
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Database migration failed:', error.message);
        process.exitCode = 1;
    } finally {
        await pool.end();
    }
}

migrate();
