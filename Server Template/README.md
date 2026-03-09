# Finance Tracker Server

Backend starter for iOS apps that need:
- secure API key storage (via Railway environment variables)
- user/auth/subscription APIs
- persistent PostgreSQL data
- GPT relay endpoints for finance insights and receipt parsing

## What This Template Includes
- Express API server (`server.js`)
- Health endpoints (`/api/health`, `/api/health/db`)
- DB-backed auth/users/subscriptions routes
- Finance AI routes:
  - `POST /api/finance/ai/insights`
  - `POST /api/finance/ai/parse-receipt`
- PostgreSQL connection pool with Railway-compatible `DATABASE_URL`
- Initial SQL schema (`db/schema.sql`)
- Database scripts (`npm run db:migrate`, `npm run db:check`)
- Railway deployment config (`railway.json`)
- Step-by-step implementation guide (`INSTRUCTIONS.md`)

## 1) App-Specific Setup Checklist
Before first push/deploy, update these:

1. `package.json`:
   - `name`
   - `description`
2. `.env` (copy from `.env.example`):
   - `APP_NAME`
   - `SERVICE_NAME`
   - `PUBLIC_API_BASE_URL`
   - `JWT_SECRET`
3. CORS:
   - set `ALLOWED_ORIGINS` to your app/web origins
4. iOS app:
   - set `API_URL` to deployed backend URL

## 2) GitHub Push Setup
If this repo is not initialized yet:

```bash
git init
git add .
git commit -m "Initial app + server template"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

## 3) Local Development
```bash
cd "Server Template"
cp .env.example .env
npm install
npm run db:check
npm run db:migrate
npm run dev
```

Server runs on `http://localhost:8000` by default.

## 4) Required Environment Variables (Production)
Minimum required values for production:

- `NODE_ENV=production`
- `PORT` (Railway sets this automatically)
- `JWT_SECRET` (long random secret)
- `DATABASE_URL` (Railway Postgres connection string)
- `ALLOWED_ORIGINS` (comma-separated trusted origins)

Recommended:
- `RATE_LIMIT_MAX`
- third-party provider keys your app needs (Stripe/OpenAI/etc)
- `OPENAI_API_KEY`
- `OPENAI_MODEL` (optional, defaults to `gpt-4.1-mini`)

## 5) Railway Deployment
1. Push repository to GitHub.
2. In Railway, create project from GitHub repo.
3. Create two services:
   - `api` (this Node server)
   - `postgres` (Railway PostgreSQL)
4. In the `api` service variables, set:
   - `NODE_ENV=production`
   - `JWT_SECRET=<generated-secret>`
   - `ALLOWED_ORIGINS=<your-prod-origins>`
   - provider API keys needed by your app
5. Add `DATABASE_URL` to `api` service from Railway Postgres reference.
6. Run migration command once:
   - `npm run db:migrate`
7. Verify:
   - `GET /api/health`
   - `GET /api/health/db`

## 6) Database Notes
- Initial schema is in `db/schema.sql`.
- Add new schema changes by creating SQL migration files and applying them in order.
- Current schema includes core tables for:
  - `users`
  - `subscriptions`
  - `app_settings`

## 7) Security Notes
- Never commit `.env` or real secrets.
- Store API keys in Railway environment variables, not in source.
- Rotate `JWT_SECRET` and provider keys if exposed.
- Use server-side API calls for sensitive provider integrations (never from iOS directly with secret keys).

## 8) Next Steps Per App
- Add webhook handlers (App Store / Stripe) if subscriptions are used.
- Add tests for auth + subscription lifecycle.
- Extend schema for app-specific entities and add route modules per feature spec.
