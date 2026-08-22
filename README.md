# Finance Tracker iOS

Production-ready SwiftUI finance tracker with local-first storage, Firebase sync, and Railway-hosted Claude relay endpoints.

## Current Product Scope
- Dashboard with monthly/weekly totals and budget status
- Expense tracking with search, categories, and delete actions
- Recurring expenses with automatic due-date posting
- Profile management and JSON data export
- Action-capable AI assistant for analysis plus confirmation-gated transaction, budget, and recurring-bill management
- AI receipt and financial-image parsing

## Architecture Summary
- iOS storage: local cache (`UserDefaults`) + Firebase sync via `DatabaseManager`
- User identity: local profile persisted on device and synced to Firebase
- AI security: iOS app calls your backend (`API_URL`), backend uses `ANTHROPIC_API_KEY` from Railway vars
- Backend routes for AI:
  - `POST /api/finance/ai/assistant`
  - `POST /api/finance/ai/insights`
  - `POST /api/finance/ai/parse-receipt`

## Quick Start

```bash
# iOS
make build
make test

# Server
cd Server
npm install
npm run dev
```

Set `API_URL` in iOS config to your server base URL.

## Release Docs
- Shipment checklist: [APP_STORE_PREP.md](APP_STORE_PREP.md)
- Privacy policy draft: [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
- Firebase setup: [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
- Server deployment: [Server/README.md](Server/README.md)

## Railway Deploy Note
- This repo includes root-level `railway.json` and `package.json` so Railway can deploy directly from repo root while running the backend from `Server/`.
- This repo now includes root-level `.env.example` so Railway can detect/suggest required backend variable names in the Variables UI.

## Key Files
- App entry: `App Template/App.swift`
- Composition root: `App Template/AppEnvironment.swift`
- Finance state: `App Template/Managers/FinanceManager.swift`
- AI orchestration: `App Template/Managers/FinanceAIManager.swift`
- Server AI routes: `Server/routes/finance.js`
