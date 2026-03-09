# Privacy Policy - Finance Tracker iOS

Effective date: March 9, 2026

## Overview
Finance Tracker iOS is designed to help users track personal expenses and recurring payments. We store sensitive API keys on our backend infrastructure (Railway) and do not embed provider secret keys in the mobile app.

## Data We Process
- Profile data: display name, email (user-provided)
- Finance data: expenses, recurring expense entries, categories, notes
- AI inputs: user prompts and receipt text submitted for parsing or insights
- Diagnostics: operational logs for app/server reliability

## Where Data Is Stored
- On device: local app storage for app state and fast startup
- Cloud sync: Firebase (profile and finance state)
- AI processing: prompts/receipt text are sent to our backend, then relayed to the OpenAI API

## How We Use Data
- Provide core expense tracking functionality
- Sync user finance data between sessions/devices
- Generate AI-based finance insights and structured receipt drafts
- Detect and debug service failures

## Data Sharing
We share data only with service providers required for app functionality:
- Firebase (cloud storage/sync)
- Railway (backend hosting)
- OpenAI (AI generation/receipt parsing via backend relay)

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

## Security
- Provider API secrets are stored as server-side environment variables.
- App-to-server calls use HTTPS.
- Access to infrastructure is restricted to authorized maintainers.

## Children's Privacy
This app is not intended for children under 13.

## Contact
For privacy questions or deletion requests, contact:
- Support URL: https://github.com/AgentScienceandResearch/Finance-Tracker-iOS/issues
