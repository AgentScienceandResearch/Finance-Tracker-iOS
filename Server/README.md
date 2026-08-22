# Finance Tracker Backend (Railway)

Express backend for Finance Tracker iOS.

## Purpose
- Keep provider secrets off-device (`ANTHROPIC_API_KEY` stored in Railway variables)
- Provide Claude relay endpoints for the iOS app
- Keep optional auth/subscription template routes available for future expansion

## Active Finance AI Endpoints
- `POST /api/finance/ai/assistant`
- `POST /api/finance/ai/insights`
- `POST /api/finance/ai/parse-receipt`
- `POST /api/finance/ai/parse-image`
- `POST /api/finance/ai/category-insight`

## Setup

```bash
cd Server
cp .env.example .env
npm install
npm run dev
```

Server default URL: `http://localhost:8000`

## Required Railway Variables
- `NODE_ENV=production`
- `PORT` (Railway sets automatically)
- `ANTHROPIC_API_KEY`
- `CLAUDE_MODEL` (optional, default `claude-haiku-4-5`)
- `JWT_SECRET`
- `ALLOWED_ORIGINS`
- `RATE_LIMIT_MAX` (recommended, default `100`)

`DATABASE_URL` is optional if you only use AI relay endpoints.  
It is required for DB-backed routes (`/api/auth`, `/api/users`, `/api/subscriptions`).

If you want deployment to fail fast on missing production vars, set:
- `STRICT_ENV_VALIDATION=true`

## Set Railway Variables Quickly (CLI)
Railway does not auto-create variables from GitHub files. Use the helper script:

```bash
cd Server
./scripts/set-railway-vars.sh \
  --anthropic-key "<your-anthropic-key>" \
  --claude-model "claude-haiku-4-5" \
  --allowed-origins "https://your-app.example.com" \
  --service "<your-railway-service-name>" \
  --environment "production"
```

If `--jwt-secret` is omitted, the script generates a secure random one.

Or use raw editor template:
- [railway.variables.example](./railway.variables.example)

## Local `.env` Minimum
For local server startup, set at least:
- `NODE_ENV=development`
- `PORT=8000`
- `JWT_SECRET=<any-long-dev-secret>`
- `ALLOWED_ORIGINS=http://localhost:3000`
- `ANTHROPIC_API_KEY=<your-key>`
- `CLAUDE_MODEL=claude-haiku-4-5`
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
