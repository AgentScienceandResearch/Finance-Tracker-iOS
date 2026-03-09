# Quick Start

This guide gets the template running locally in a few minutes.

## Prerequisites

- macOS with Xcode installed
- Homebrew
- iOS simulator runtime available in Xcode

Optional (recommended):

- `swiftlint`
- `swiftformat`
- Firebase project (if you want real cloud persistence)

## 1) Install Tooling

```bash
make tools
```

## 2) Bootstrap

```bash
make bootstrap
```

What this does:

- validates tool availability
- generates `FinanceTrackeriOS.xcodeproj` from `project.yml`
- creates `App Template/.env` from `App Template/.env.example` if missing

## 3) Build and Test

```bash
make build
make test
```

These commands preserve manual Xcode project edits. They only generate the project if it is missing.

## 4) Open in Xcode

```bash
open FinanceTrackeriOS.xcodeproj
```

Run scheme `TemplateApp` on a simulator.

## Runtime Configuration

Edit `App Template/.env` (local) and/or `Config/xcconfigs/*.xcconfig`:

- `APP_ENV`
- `API_URL`
- `GITHUB_TOKEN`
- `ANALYTICS_PROVIDER` (`noop`, `console`, `firebase`)

`AppConfig` resolves values from environment first, then Info.plist, then defaults.

## Firebase (Optional)

The app works without Firebase because `DatabaseManager` falls back to in-memory storage.

If you want Firebase:

1. follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
2. add `GoogleService-Info.plist` to the app target
3. wire Firebase SDK and initialization in app bootstrap

## Common Commands

```bash
make generate-project
make build-fresh
make test-fresh
make format
make lint
make ci
make clean
```

## Troubleshooting

- Build fails on simulator destination:
  - run `xcodebuild -showdestinations -project FinanceTrackeriOS.xcodeproj -scheme TemplateApp`
  - update `DESTINATION` in `Makefile` if needed

- `xcodegen` missing:
  - `brew install xcodegen`

- Local API unreachable:
  - verify `API_URL` and backend process status
