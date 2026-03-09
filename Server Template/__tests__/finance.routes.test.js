const request = require('supertest');
const axios = require('axios');
const { pool } = require('../db/pool');

jest.mock('axios');

const app = require('../server');

describe('Finance AI routes', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.OPENAI_API_KEY = 'test-openai-key';
        process.env.OPENAI_MODEL = 'gpt-4.1-mini';
    });

    afterAll(() => {
        delete process.env.OPENAI_API_KEY;
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
        axios.post.mockResolvedValueOnce({
            data: {
                output_text: 'You can reduce dining spending by 10% this month.'
            }
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

    test('POST /api/finance/ai/parse-receipt normalizes category and response', async () => {
        axios.post.mockResolvedValueOnce({
            data: {
                output_text: "```json\n{\"merchant\":\"Corner Cafe\",\"amount\":18.5,\"category\":\"Invalid Category\",\"purchaseDate\":\"2026-03-01\",\"notes\":\"latte and sandwich\"}\n```"
            }
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
