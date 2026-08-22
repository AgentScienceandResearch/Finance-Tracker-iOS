const request = require('supertest');
const Anthropic = require('@anthropic-ai/sdk');
const { pool } = require('../db/pool');

jest.mock('@anthropic-ai/sdk');

const app = require('../server');

const mockCreate = jest.fn();
Anthropic.mockImplementation(() => ({
    messages: { create: mockCreate }
}));

describe('Finance AI routes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
        process.env.CLAUDE_MODEL = 'claude-haiku-4-5';
    });

    afterAll(() => {
        delete process.env.ANTHROPIC_API_KEY;
        return pool.end();
    });

    test('POST /api/finance/ai/insights validates payload', async () => {
        const response = await request(app)
            .post('/api/finance/ai/insights')
            .send({ prompt: 'How am I doing?' });

        expect(response.status).toBe(400);
        expect(response.body.error).toBe('Finance summary is required.');
    });

    test('POST /api/finance/ai/insights returns assistant message', async () => {
        mockCreate.mockResolvedValueOnce({
            content: [{ type: 'text', text: 'You can reduce dining spending by 10% this month.' }]
        });

        const response = await request(app)
            .post('/api/finance/ai/insights')
            .send({
                prompt: 'Give me one savings idea',
                financeSummary: 'This month total: $950'
            });

        expect(response.status).toBe(200);
        expect(response.body.message).toContain('reduce dining spending');
    });

    test('POST /api/finance/ai/assistant requires a finance snapshot', async () => {
        const response = await request(app)
            .post('/api/finance/ai/assistant')
            .send({ prompt: 'Add lunch for $12' });

        expect(response.status).toBe(400);
        expect(response.body.error).toBe('Finance snapshot is required.');
    });

    test('POST /api/finance/ai/assistant returns native tool calls for review', async () => {
        const transactionId = 'ad5f0a78-c013-4b68-9ed1-95c722c16f5a';
        mockCreate.mockResolvedValueOnce({
            content: [
                { type: 'text', text: 'I prepared those two changes for your review.' },
                {
                    type: 'tool_use',
                    id: 'tool-add',
                    name: 'add_transaction',
                    input: {
                        title: 'Lunch',
                        amount: 12,
                        category: 'Food & Dining',
                        date: '2026-08-22'
                    }
                },
                {
                    type: 'tool_use',
                    id: 'tool-delete',
                    name: 'delete_transaction',
                    input: { transactionId }
                }
            ]
        });

        const response = await request(app)
            .post('/api/finance/ai/assistant')
            .send({
                prompt: 'Add lunch for $12 and delete the old coffee charge',
                snapshot: {
                    generatedAt: '2026-08-22T12:00:00Z',
                    currencyCode: 'CAD',
                    transactions: [{ id: transactionId, title: 'Coffee', amount: 4 }],
                    recurringTransactions: []
                },
                conversation: [{ role: 'assistant', content: 'Welcome message' }]
            });

        expect(response.status).toBe(200);
        expect(response.body.message).toContain('two changes');
        expect(response.body.actions).toHaveLength(2);
        expect(response.body.actions[0]).toEqual(expect.objectContaining({
            id: 'tool-add',
            type: 'add_transaction'
        }));
        expect(response.body.actions[1].input.transactionId).toBe(transactionId);

        const requestPayload = mockCreate.mock.calls[0][0];
        expect(requestPayload.tools.map(tool => tool.name)).toEqual(expect.arrayContaining([
            'add_transaction',
            'update_transaction',
            'delete_transaction',
            'add_recurring_transaction',
            'update_recurring_transaction',
            'set_recurring_active',
            'clear_all_finance_data'
        ]));
        expect(requestPayload.messages[0].role).toBe('user');
        expect(requestPayload.messages[0].content).toContain(transactionId);
    });

    test('POST /api/finance/ai/assistant ignores unknown tool calls', async () => {
        mockCreate.mockResolvedValueOnce({
            content: [
                { type: 'text', text: 'I cannot do that.' },
                { type: 'tool_use', id: 'unknown', name: 'transfer_real_money', input: { amount: 100 } }
            ]
        });

        const response = await request(app)
            .post('/api/finance/ai/assistant')
            .send({ prompt: 'Move money', snapshot: { transactions: [], recurringTransactions: [] } });

        expect(response.status).toBe(200);
        expect(response.body.actions).toEqual([]);
    });

    test('POST /api/finance/ai/assistant rejects a clear-all call mixed with other changes', async () => {
        mockCreate.mockResolvedValueOnce({
            content: [
                { type: 'tool_use', id: 'clear', name: 'clear_all_finance_data', input: {} },
                {
                    type: 'tool_use',
                    id: 'budget',
                    name: 'set_monthly_budget',
                    input: { amount: 500 }
                }
            ]
        });

        const response = await request(app)
            .post('/api/finance/ai/assistant')
            .send({ prompt: 'Clear everything and set a budget', snapshot: { transactions: [], recurringTransactions: [] } });

        expect(response.status).toBe(200);
        expect(response.body.actions).toEqual([]);
        expect(response.body.message).toContain('separate request');
    });

    test('POST /api/finance/ai/parse-receipt normalizes category and response', async () => {
        mockCreate.mockResolvedValueOnce({
            content: [{ type: 'text', text: '{"merchant":"Corner Cafe","amount":18.5,"category":"Invalid Category","purchaseDate":"2026-03-01","notes":"latte and sandwich"}' }]
        });

        const response = await request(app)
            .post('/api/finance/ai/parse-receipt')
            .send({ rawText: 'CORNER CAFE TOTAL 18.50' });

        expect(response.status).toBe(200);
        expect(response.body.merchant).toBe('Corner Cafe');
        expect(response.body.amount).toBe(18.5);
        expect(response.body.category).toBe('Other');
        expect(response.body.purchaseDate).toBe('2026-03-01');
    });
});
