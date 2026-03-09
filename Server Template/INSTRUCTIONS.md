# Server Template Instructions

Use this folder as the backend starter for each new iOS app.

## 1) Rename and initialize for your app

1. Copy this folder into your app repo (or keep it as `Server Template/`).
2. Update `package.json`:
   - `name`: set to your backend service slug (for example: `my-app-api`)
   - `description`: describe your API domain
3. Copy environment file:
   - `cp .env.example .env`
4. Set app identity values in `.env`:
   - `APP_NAME`
   - `SERVICE_NAME`
   - `PUBLIC_API_BASE_URL`

## 2) Required environment variables

Production minimum:
- `NODE_ENV=production`
- `JWT_SECRET` (long random secret)
- `DATABASE_URL` (Railway Postgres)
- `ALLOWED_ORIGINS` (comma-separated list)

Common optional variables:
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `OPENAI_API_KEY`
- `RESEND_API_KEY`
- Apple subscription vars (`APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_KEY_PATH`)

Store all secrets in Railway Variables. Never commit real secret values.

## 3) Local setup

```bash
cd "Server Template"
npm install
cp .env.example .env
npm run db:check
npm run db:migrate
npm run dev
```

## 4) Database setup

- Core schema: `db/schema.sql`
- Migration runner: `npm run db:migrate`
- Connectivity check: `npm run db:check`

Default tables included:
- `users` (auth/profile)
- `subscriptions` (subscription lifecycle)
- `app_settings` (key/value app configuration)

For each app, extend `db/schema.sql` with app-specific entities (for example `prompts`, `journal_entries`, `ai_jobs`).

## 5) Railway deployment

1. Push repo to GitHub.
2. Create Railway project from that GitHub repo.
3. Add services:
   - API service (this Node app)
   - PostgreSQL service
4. In API service, set Railway Variables (required + optional for your app).
   - Fast path: run `./scripts/set-railway-vars.sh --openai-key ... --service ... --environment production`
   - Raw editor template: `railway.variables.example`
5. Set `DATABASE_URL` from the PostgreSQL service connection.
6. Deploy.
7. Run migration once:
   - `npm run db:migrate`
8. Verify:
   - `GET /api/health`
   - `GET /api/health/db`

`railway.json` in this folder already configures start command and health checks.

## 6) App spec checklist (per new app)

Before shipping, confirm:
- Auth requirements: email/password vs OAuth providers
- Subscription provider: App Store only vs Stripe + App Store
- Webhooks required and validated
- Database entities and indexes match product spec
- Required environment variables are documented and set in Railway
- CORS includes all production origins
- Secrets are only server-side (never in iOS client)
