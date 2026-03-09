# Finance Tracker Backend (Railway)

Express backend for Finance Tracker iOS.

## Purpose
- Keep provider secrets off-device (`OPENAI_API_KEY` stored in Railway variables)
- Provide GPT relay endpoints for iOS app
- Keep optional auth/subscription template routes available for future expansion

## Active Finance AI Endpoints
- `POST /api/finance/ai/insights`
- `POST /api/finance/ai/parse-receipt`

## Setup

```bash
cd "Server Template"
cp .env.example .env
npm install
npm run dev
```

Server default URL: `http://localhost:8000`

## Required Railway Variables
- `NODE_ENV=production`
- `PORT` (Railway sets automatically)
- `OPENAI_API_KEY`
- `OPENAI_MODEL` (optional, default `gpt-4.1-mini`)
- `JWT_SECRET`
- `DATABASE_URL`
- `ALLOWED_ORIGINS`
- `RATE_LIMIT_MAX` (recommended, default `100`)

## Local `.env` Minimum
For local server startup, set at least:
- `NODE_ENV=development`
- `PORT=8000`
- `JWT_SECRET=<any-long-dev-secret>`
- `ALLOWED_ORIGINS=http://localhost:3000`
- `OPENAI_API_KEY=<your-key>`
- either `DATABASE_URL=<postgres-url>` or `DB_*` variables from `.env.example`

## Health Checks
- `GET /api/health`
- `GET /api/health/db`

## Testing

```bash
npm test -- --runInBand
```

## Deploy
1. Push GitHub repo.
2. Create Railway project from repo.
3. Add Postgres + API services.
4. Set variables above.
5. Run `npm run db:migrate` once.
6. Point iOS `API_URL` to Railway API URL.
