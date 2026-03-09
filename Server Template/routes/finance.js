const express = require('express');
const axios = require('axios');

const router = express.Router();

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const OPENAI_ENDPOINT = 'https://api.openai.com/v1/responses';

const ALLOWED_CATEGORIES = new Set([
    'Food & Dining',
    'Transportation',
    'Housing',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Health',
    'Travel',
    'Education',
    'Subscriptions',
    'Income Offset',
    'Other'
]);

router.post('/ai/insights', async (req, res) => {
    try {
        const { prompt, financeSummary } = req.body;

        if (!prompt || typeof prompt !== 'string') {
            return res.status(400).json({ error: 'Prompt is required.' });
        }

        if (!financeSummary || typeof financeSummary !== 'string') {
            return res.status(400).json({ error: 'Finance summary is required.' });
        }

        if (prompt.length > 4_000 || financeSummary.length > 12_000) {
            return res.status(400).json({ error: 'Payload is too large.' });
        }

        const instructions = [
            'You are a practical personal finance assistant.',
            'Keep responses concise, concrete, and action-oriented.',
            'If context is incomplete, explicitly list missing data.'
        ].join(' ');

        const input = `Finance summary:\n${financeSummary}\n\nUser request:\n${prompt}`;

        const text = await callOpenAI({ instructions, input });
        if (!text) {
            return res.status(502).json({ error: 'OpenAI returned an empty response.' });
        }

        return res.json({
            message: text,
            model: OPENAI_MODEL
        });
    } catch (error) {
        return res.status(502).json({
            error: error.message || 'Failed to generate AI insight.'
        });
    }
});

router.post('/ai/parse-receipt', async (req, res) => {
    try {
        const { rawText } = req.body;

        if (!rawText || typeof rawText !== 'string') {
            return res.status(400).json({ error: 'rawText is required.' });
        }

        if (rawText.length > 12_000) {
            return res.status(400).json({ error: 'rawText is too large.' });
        }

        const instructions = [
            'Extract transaction details from receipt text.',
            'Return only JSON with keys: merchant, amount, category, purchaseDate, notes.',
            'amount must be a number, purchaseDate must be YYYY-MM-DD, notes can be null.',
            `category must be one of: ${Array.from(ALLOWED_CATEGORIES).join(', ')}`
        ].join(' ');

        const text = await callOpenAI({ instructions, input: rawText });
        const parsed = parseJSONPayload(text);

        if (!parsed || typeof parsed !== 'object') {
            return res.status(502).json({ error: 'Unable to parse structured receipt response.' });
        }

        const merchant = typeof parsed.merchant === 'string' && parsed.merchant.trim() ? parsed.merchant.trim() : 'Receipt Expense';
        const amount = Number(parsed.amount);
        if (!Number.isFinite(amount) || amount < 0) {
            return res.status(502).json({ error: 'AI returned an invalid amount.' });
        }

        const rawCategory = typeof parsed.category === 'string' ? parsed.category.trim() : 'Other';
        const category = ALLOWED_CATEGORIES.has(rawCategory) ? rawCategory : 'Other';

        const purchaseDate = typeof parsed.purchaseDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(parsed.purchaseDate)
            ? parsed.purchaseDate
            : new Date().toISOString().slice(0, 10);

        const notes = typeof parsed.notes === 'string' ? parsed.notes.trim() : null;

        return res.json({
            merchant,
            amount,
            category,
            purchaseDate,
            notes
        });
    } catch (error) {
        return res.status(502).json({
            error: error.message || 'Failed to parse receipt.'
        });
    }
});

async function callOpenAI({ instructions, input }) {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
        throw new Error('OPENAI_API_KEY is not configured on the server.');
    }

    try {
        const response = await axios.post(
            OPENAI_ENDPOINT,
            {
                model: OPENAI_MODEL,
                instructions,
                input
            },
            {
                headers: {
                    Authorization: `Bearer ${apiKey}`,
                    'Content-Type': 'application/json'
                },
                timeout: 45000
            }
        );

        return extractOutputText(response.data);
    } catch (error) {
        const providerMessage = error?.response?.data?.error?.message;
        const statusCode = error?.response?.status;
        if (providerMessage) {
            throw new Error(`OpenAI error${statusCode ? ` (${statusCode})` : ''}: ${providerMessage}`);
        }
        throw new Error('OpenAI request failed.');
    }
}

function extractOutputText(payload) {
    if (!payload || typeof payload !== 'object') {
        return null;
    }

    if (typeof payload.output_text === 'string' && payload.output_text.trim()) {
        return payload.output_text.trim();
    }

    if (Array.isArray(payload.output_text)) {
        const joined = payload.output_text.filter(Boolean).join('\n').trim();
        if (joined) {
            return joined;
        }
    }

    if (!Array.isArray(payload.output)) {
        return null;
    }

    const chunks = [];
    for (const item of payload.output) {
        if (!item || !Array.isArray(item.content)) continue;
        for (const content of item.content) {
            if (typeof content.text === 'string' && content.text.trim()) {
                chunks.push(content.text.trim());
                continue;
            }

            if (content && content.text && typeof content.text.value === 'string' && content.text.value.trim()) {
                chunks.push(content.text.value.trim());
            }
        }
    }

    const text = chunks.join('\n').trim();
    return text || null;
}

function parseJSONPayload(text) {
    if (!text || typeof text !== 'string') {
        return null;
    }

    const trimmed = text.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
            return JSON.parse(trimmed);
        } catch (_) {
            return null;
        }
    }

    const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (!fencedMatch) {
        return null;
    }

    try {
        return JSON.parse(fencedMatch[1]);
    } catch (_) {
        return null;
    }
}

module.exports = router;
