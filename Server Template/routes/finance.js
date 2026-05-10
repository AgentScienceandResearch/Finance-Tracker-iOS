const express = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const { getClaudeConfig } = require('../config/env');

const router = express.Router();

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
    'Medical',
    'Personal Care',
    'Fitness',
    'Pets',
    'Gifts & Donations',
    'Insurance',
    'Home Maintenance',
    'Savings',
    'Business',
    'Income',
    'Other'
]);

// ─── System prompts ────────────────────────────────────────────────────────────

const INSIGHTS_SYSTEM = `You are a smart, practical personal finance assistant built into Finance Tracker: AI — a mobile app that helps people track expenses, manage recurring bills, and build healthier money habits.

Each request includes a real-time snapshot of the user's finances: their monthly and weekly totals, recurring bill load, recent transactions, and upcoming charges. Use this data directly in your response — reference specific amounts and categories rather than speaking in generalities.

Your job:
- Answer the user's specific question or fulfill their request using the financial data provided
- Give concrete, actionable advice (specific dollar amounts to reduce, which categories are high, realistic savings targets based on their actual numbers)
- Identify patterns or flag potential issues when relevant, such as a heavy recurring bill load, spending concentrated in one category, or an upcoming charge that might cause a shortfall
- When the user asks for a budget, build it from the numbers in the summary — don't guess

Tone: Warm, direct, and non-judgmental. You're a knowledgeable friend who happens to be good with money, not a financial advisor reading from a script. Avoid hedging every sentence. Be specific and useful.

Response length: Concise. Aim for 2–4 short paragraphs or a tight bulleted list. If the question is simple, answer simply.

Limitations: You only know what is in the summary provided. If the user asks about taxes, investments, insurance products, or anything outside their tracked expenses, acknowledge the limit briefly and suggest they consult a professional for those topics. Never fabricate data that isn't in the summary.

Format: Plain conversational text. No markdown formatting, no asterisks, no headers, no emoji. Write naturally as you would in a chat message.`;

const RECEIPT_SYSTEM = `You extract transaction details from receipt text and return a single JSON object. No other output — only the JSON.

Output format (all keys required):
{
  "merchant": "<store or business name, cleaned and trimmed, max 80 chars — use 'Receipt Expense' if not found>",
  "amount": <final total paid as a number, no symbols or commas>,
  "category": "<one of the allowed categories below>",
  "purchaseDate": "<YYYY-MM-DD — use today's date if not found>",
  "notes": "<brief useful note about the purchase, or null>"
}

Allowed categories (use exactly as written):
Food & Dining, Transportation, Housing, Utilities, Entertainment, Shopping, Health, Travel, Education, Subscriptions, Income Offset, Medical, Personal Care, Fitness, Pets, Gifts & Donations, Insurance, Home Maintenance, Savings, Business, Income, Other

Rules:
- amount: use the final total or grand total shown on the receipt. If multiple totals appear, prefer the largest plausible one (the amount actually paid after discounts and tax).
- merchant: clean up the name (remove store numbers, excessive punctuation). Capitalize properly.
- category: infer from the merchant name and items purchased. When in doubt, use Other.
- purchaseDate: parse any date format found on the receipt and convert to YYYY-MM-DD.
- notes: include only if there is something genuinely useful (e.g., "Split meal with two people", "Includes $12.50 tip", "Return/refund receipt"). Use null otherwise.

Respond with only the JSON object — no explanation, no markdown code fences, no surrounding text.`;

// ─── Routes ───────────────────────────────────────────────────────────────────

router.post('/ai/insights', async (req, res) => {
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

    try {
        const userMessage = `Here is my current financial snapshot:\n\n${financeSummary}\n\nMy question: ${prompt}`;
        const text = await callClaude({ system: INSIGHTS_SYSTEM, userMessage, maxTokens: 1024 });

        if (!text) {
            return res.status(502).json({ error: 'Claude returned an empty response.' });
        }

        return res.json({ message: text, model: getClaudeConfig().model });
    } catch (error) {
        return res.status(502).json({ error: error.message || 'Failed to generate AI insight.' });
    }
});

router.post('/ai/parse-receipt', async (req, res) => {
    const { rawText } = req.body;

    if (!rawText || typeof rawText !== 'string') {
        return res.status(400).json({ error: 'rawText is required.' });
    }

    if (rawText.length > 12_000) {
        return res.status(400).json({ error: 'rawText is too large.' });
    }

    try {
        const text = await callClaude({ system: RECEIPT_SYSTEM, userMessage: rawText, maxTokens: 512 });
        const parsed = parseJSONPayload(text);

        if (!parsed || typeof parsed !== 'object') {
            return res.status(502).json({ error: 'Unable to parse structured receipt response.' });
        }

        const merchant = typeof parsed.merchant === 'string' && parsed.merchant.trim()
            ? parsed.merchant.trim().slice(0, 80)
            : 'Receipt Expense';

        const amount = Number(parsed.amount);
        if (!Number.isFinite(amount) || amount < 0) {
            return res.status(502).json({ error: 'AI returned an invalid amount.' });
        }

        const rawCategory = typeof parsed.category === 'string' ? parsed.category.trim() : 'Other';
        const category = ALLOWED_CATEGORIES.has(rawCategory) ? rawCategory : 'Other';

        const purchaseDate = typeof parsed.purchaseDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(parsed.purchaseDate)
            ? parsed.purchaseDate
            : new Date().toISOString().slice(0, 10);

        const notes = typeof parsed.notes === 'string' && parsed.notes.trim() ? parsed.notes.trim() : null;

        return res.json({ merchant, amount, category, purchaseDate, notes });
    } catch (error) {
        return res.status(502).json({ error: error.message || 'Failed to parse receipt.' });
    }
});

// ─── Claude helper ─────────────────────────────────────────────────────────────

async function callClaude({ system, userMessage, maxTokens }) {
    const config = getClaudeConfig();
    if (!config.apiKey) {
        throw new Error('ANTHROPIC_API_KEY is not configured on the server.');
    }

    const client = new Anthropic({ apiKey: config.apiKey });

    try {
        const response = await client.messages.create({
            model: config.model,
            max_tokens: maxTokens,
            system,
            messages: [{ role: 'user', content: userMessage }]
        });

        const block = response.content.find(b => b.type === 'text');
        return block ? block.text.trim() : null;
    } catch (error) {
        if (error instanceof Anthropic.APIError) {
            throw new Error(`Claude API error (${error.status}): ${error.message}`);
        }
        throw new Error('Claude request failed.');
    }
}

// ─── JSON parsing ──────────────────────────────────────────────────────────────

function parseJSONPayload(text) {
    if (!text || typeof text !== 'string') return null;

    const trimmed = text.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try { return JSON.parse(trimmed); } catch (_) { /* fall through */ }
    }

    const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fencedMatch) {
        try { return JSON.parse(fencedMatch[1]); } catch (_) { /* fall through */ }
    }

    // Last resort: find first {...} block in the text
    const objectMatch = trimmed.match(/\{[\s\S]*\}/);
    if (objectMatch) {
        try { return JSON.parse(objectMatch[0]); } catch (_) { /* fall through */ }
    }

    return null;
}

module.exports = router;
