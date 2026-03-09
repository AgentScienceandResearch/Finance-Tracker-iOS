# App Store Prep Checklist (Finance Tracker iOS)

Last updated: March 9, 2026

## Build Status
- iOS unit tests are passing.
- Finance app screens are implemented: Dashboard, Expenses, Recurring, Settings.
- Data architecture is set to local-first + Firebase sync.
- GPT calls are proxied through Railway server (`/api/finance/ai/*`).

## Required Before Beta/Release
- Add Firebase configuration to iOS target (`GoogleService-Info.plist`) and verify Firestore rules.
- Set Railway environment variable `OPENAI_API_KEY` for the server service.
- Set production `ALLOWED_ORIGINS`, `JWT_SECRET`, and `DATABASE_URL` in Railway.
- Change bundle id/team/signing in Xcode for your Apple Developer account.

## iOS Release Checklist
- Update app name and bundle identifiers from template defaults.
- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- Validate app icon set and launch branding.
- Verify portrait-only behavior across iPhone sizes.
- Test offline startup and reconnection sync behavior.
- Test first-run profile creation and edit flow.
- Test receipt parsing with real OCR text samples.
- Test destructive actions (`Clear All Data`) with confirmation.
- Validate accessibility labels, Dynamic Type, and VoiceOver on key flows.

## Privacy and Compliance
- Publish privacy policy (see `PRIVACY_POLICY.md`).
- App Store Connect privacy nutrition labels must disclose:
  - Financial info entered by user
  - User content entered into AI prompts/receipt text
  - Diagnostics (if analytics enabled)
- Ensure no provider secret keys are stored in iOS app binaries.

## Server Release Checklist (Railway)
- Deploy from `main` branch.
- Run `npm run db:migrate` once after first deploy.
- Verify health checks:
  - `GET /api/health`
  - `GET /api/health/db`
- Verify finance AI routes:
  - `POST /api/finance/ai/insights`
  - `POST /api/finance/ai/parse-receipt`

## App Store Connect Submission Checklist
- Add screenshots for all supported iPhone sizes.
- Add app description, keywords, and support URL.
- Add privacy policy URL and contact email.
- Upload release build from Xcode Organizer.
- Complete export compliance questions.
- Submit for TestFlight external testing first, then App Review.

## Post-Submission Monitoring
- Check Crash logs and analytics in first 24h after release.
- Monitor Railway logs for AI route errors/timeouts.
- Validate Firestore write/read error rates and quotas.
