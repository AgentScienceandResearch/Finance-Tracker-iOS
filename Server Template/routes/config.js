const express = require('express');
const { getServerConfig } = require('../config/env');

const router = express.Router();

// Public config values safe to expose to the mobile client.
// logo.dev tokens are client-side keys designed to appear in image URLs.
router.get('/', (req, res) => {
    const config = getServerConfig();
    res.json({
        logoDevToken: config.logoDevToken
    });
});

module.exports = router;
