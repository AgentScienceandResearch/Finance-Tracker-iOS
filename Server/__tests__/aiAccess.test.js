const request = require('supertest');
const Anthropic = require('@anthropic-ai/sdk');

jest.mock('@anthropic-ai/sdk');
jest.mock('../db/pool', () => ({
    pool: {
        query: jest.fn().mockRejectedValue(new Error('no database in tests')),
        end: jest.fn()
    }
}));

const mockVerify = jest.fn();
jest.mock('@apple/app-store-server-library', () => {
    const actual = jest.requireActual('@apple/app-store-server-library');
    return {
        ...actual,
        SignedDataVerifier: jest.fn().mockImplementation(() => ({
            verifyAndDecodeTransaction: mockVerify
        }))
    };
});

const app = require('../server');
const { resetAIAccessStateForTests } = require('../middleware/aiAccess');

const mockCreate = jest.fn();
Anthropic.mockImplementation(() => ({ messages: { create: mockCreate } }));

const DEVICE_ID = '7f3d2c1b-4a5e-4f60-9b8a-1c2d3e4f5a6b';
const MONTHLY = 'com.agentscienceandresearch.financetrackerios.monthly';

function askAssistant(headers = {}) {
    return request(app)
        .post('/api/finance/ai/assistant')
        .set(headers)
        .send({ prompt: 'How am I doing?', snapshot: { transactions: [] } });
}

function scanReceipt(headers = {}) {
    return request(app)
        .post('/api/finance/ai/parse-receipt')
        .set(headers)
        .send({ rawText: 'COFFEE SHOP TOTAL 4.50' });
}

describe('AI access gating', () => {
    let warn;

    beforeAll(() => {
        warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    });

    afterAll(() => warn.mockRestore());

    beforeEach(() => {
        jest.clearAllMocks();
        resetAIAccessStateForTests();
        process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
        process.env.FREE_AI_MESSAGES_PER_MONTH = '2';
        delete process.env.LEGACY_AI_ACCESS;
        mockCreate.mockResolvedValue({ content: [{ type: 'text', text: 'Looking good.' }] });
    });

    test('free device gets the monthly allowance, then a 402', async () => {
        const first = await askAssistant({ 'X-Device-ID': DEVICE_ID });
        expect(first.status).toBe(200);
        expect(first.headers['x-ai-plan']).toBe('free');
        expect(first.headers['x-ai-free-remaining']).toBe('1');

        const second = await askAssistant({ 'X-Device-ID': DEVICE_ID });
        expect(second.status).toBe(200);
        expect(second.headers['x-ai-free-remaining']).toBe('0');

        const third = await askAssistant({ 'X-Device-ID': DEVICE_ID });
        expect(third.status).toBe(402);
        expect(third.body.code).toBe('subscription_required');
        expect(mockCreate).toHaveBeenCalledTimes(2);
    });

    test('failed AI calls are refunded', async () => {
        mockCreate.mockRejectedValueOnce(new Error('upstream down'));
        const failed = await askAssistant({ 'X-Device-ID': DEVICE_ID });
        expect(failed.status).toBe(502);

        // Let the finish handler run before the next request.
        await new Promise(resolve => setImmediate(resolve));

        const ok = await askAssistant({ 'X-Device-ID': DEVICE_ID });
        expect(ok.status).toBe(200);
        expect(ok.headers['x-ai-free-remaining']).toBe('1');
    });

    test('receipt scanning is Pro only', async () => {
        const response = await scanReceipt({ 'X-Device-ID': DEVICE_ID });
        expect(response.status).toBe(402);
        expect(mockCreate).not.toHaveBeenCalled();
    });

    test('a verified active subscription unlocks Pro routes', async () => {
        mockVerify.mockResolvedValue({
            productId: MONTHLY,
            expiresDate: Date.now() + 86_400_000
        });
        mockCreate.mockResolvedValueOnce({
            content: [{ type: 'text', text: '{"merchant":"Coffee Shop","amount":4.5,"category":"Food & Dining","purchaseDate":"2026-10-07","notes":null}' }]
        });

        const response = await scanReceipt({ 'X-Device-ID': DEVICE_ID, 'X-App-Store-Transaction': 'signed.jws.value' });
        expect(response.status).toBe(200);
        expect(response.headers['x-ai-plan']).toBe('pro');
    });

    test('expired, revoked, or unknown-product transactions do not unlock Pro', async () => {
        const headers = { 'X-Device-ID': DEVICE_ID };
        const cases = [
            { productId: MONTHLY, expiresDate: Date.now() - 1000 },
            { productId: MONTHLY, expiresDate: Date.now() + 86_400_000, revocationDate: Date.now() },
            { productId: 'some.other.product', expiresDate: Date.now() + 86_400_000 }
        ];

        for (const [index, payload] of cases.entries()) {
            mockVerify.mockResolvedValueOnce(payload);
            const response = await scanReceipt({ ...headers, 'X-App-Store-Transaction': `jws-${index}` });
            expect(response.status).toBe(402);
        }
    });

    test('a forged transaction falls back to the free plan', async () => {
        mockVerify.mockRejectedValue(new Error('bad signature'));
        const response = await askAssistant({ 'X-Device-ID': DEVICE_ID, 'X-App-Store-Transaction': 'forged' });
        expect(response.status).toBe(200);
        expect(response.headers['x-ai-plan']).toBe('free');
    });

    test('legacy clients are allowed by default and denied when switched off', async () => {
        expect((await askAssistant()).status).toBe(200);

        process.env.LEGACY_AI_ACCESS = 'deny';
        expect((await askAssistant()).status).toBe(402);
    });

    test('rejects malformed device identifiers', async () => {
        const response = await askAssistant({ 'X-Device-ID': 'not-a-uuid' });
        expect(response.status).toBe(400);
    });
});
