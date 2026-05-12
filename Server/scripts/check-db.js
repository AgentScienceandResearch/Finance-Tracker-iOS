#!/usr/bin/env node
require('dotenv').config();

const { pool } = require('../db/pool');

async function checkDatabase() {
    try {
        const result = await pool.query('SELECT NOW() as now');
        console.log(`Database reachable. Server time: ${result.rows[0].now}`);
    } catch (error) {
        console.error('Database not reachable:', error.message);
        process.exitCode = 1;
    } finally {
        await pool.end();
    }
}

checkDatabase();
