# Privacy Policy - Finance Tracker iOS

Effective date: August 22, 2026

## Overview
Finance Tracker iOS is designed to help users track personal expenses and recurring payments. We store sensitive API keys on our backend infrastructure (Railway) and do not embed provider secret keys in the mobile app.

## Data We Process
- Profile data: display name, email (user-provided)
- Finance data: expenses, recurring expense entries, categories, notes
- AI inputs: user prompts, recent assistant conversation context, receipt text, and a current finance snapshot (transactions, recurring items, budget, categories, dates, identifiers, and notes) when the user asks the assistant for help
- Diagnostics: operational logs for app/server reliability

## Where Data Is Stored
- On device: local app storage for app state and fast startup
- Cloud sync: Firebase (profile and finance state)
- AI processing: assistant prompts and the finance context needed to answer them, or receipt text submitted for parsing, are sent to our backend and relayed to the Anthropic API

## How We Use Data
- Provide core expense tracking functionality
- Sync user finance data between sessions/devices
- Generate AI-based finance guidance, propose user-requested finance actions, and create structured receipt drafts
- Detect and debug service failures

## Data Sharing
We share data only with service providers required for app functionality:
- Firebase (cloud storage/sync)
- Railway (backend hosting)
- Anthropic (AI generation, finance-action proposals, and receipt parsing via backend relay)

We do not sell personal data.

## Data Retention
- Local data remains on device until user clears app data or removes the app.
- Firebase data remains until deleted by the user or app operator.
- Server logs are retained for operational/security purposes for a limited period.

## User Controls
Users can:
- Edit profile data in Settings
- Delete individual expenses/recurring items
- Export data from Settings
- Clear all local and synced finance data from Settings
- Review and approve or dismiss every AI-proposed finance change before it is applied

## Security
- Provider API secrets are stored as server-side environment variables.
- App-to-server calls use HTTPS.
- Access to infrastructure is restricted to authorized maintainers.

## Children's Privacy
This app is not intended for children under 13.

## Contact
For privacy questions or deletion requests, contact:
- Support URL: https://agentscienceandresearch.github.io/Finance-Tracker-iOS/support.html
