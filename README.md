# iOS App Template

Production-minded SwiftUI template with a futuristic liquid-glass design system, protocol-first architecture, and testable app flows.

## What You Get

- SwiftUI app target with `Authentication`, `Paywall`, and `MainTab` flows
- Liquid-glass component library (`GlassCard`, `FloatingGlassCard`, animated backgrounds, chips, orb buttons)
- Typed runtime config via `AppConfig` (`APP_ENV`, `API_URL`, `GITHUB_TOKEN`)
- Protocol-first managers and flow view models for easy mocking
- Repository layer for user and StoreKit boundaries
- Observability primitives (`Logging`, `AnalyticsTracking`) with OSLog default logger
- Firebase-compatible persistence with in-memory fallback for local/demo runs
- XcodeGen project generation + Makefile + CI workflow
- Unit and smoke tests (20 tests currently passing)

## 5-Minute Start

```bash
# 1) install tools (once)
make tools

# 2) bootstrap project files and local env template
make bootstrap

# 3) build
make build

# 4) run tests
make test
```

Open `IOSAppTemplate.xcodeproj` (or `IOSAppTemplate.xcworkspace`) and run `TemplateApp` on an iOS simulator.

## Core Commands

- `make generate-project`: regenerate Xcode project from `project.yml`
- `make ensure-project`: generate only if `IOSAppTemplate.xcodeproj` is missing
- `make format`: run SwiftFormat
- `make lint`: run SwiftLint (strict)
- `make build`: Debug build for simulator (preserves manual Xcode project edits)
- `make test`: run unit tests (preserves manual Xcode project edits)
- `make build-fresh`: regenerate project, then build
- `make test-fresh`: regenerate project, then test
- `make ci`: generate + lint + build + test
- `make demo-no-firebase`: build path that does not require Firebase wiring

## Xcode Project Editing

`make build` and `make test` no longer regenerate the project each run, so manual edits you make in Xcode are preserved.

When you change `project.yml` and want to sync generated settings, run:

```bash
make generate-project
```

## Project Layout

```text
App Template/
  App.swift
  AppEnvironment.swift
  Config/AppConfig.swift
  Design/ (Theme + liquid-glass components)
  Managers/ (auth/subscription/database state)
  Repositories/ (user/storekit boundaries)
  Services/ (API + GitHub integration)
  ViewModels/ (AuthenticationFlow, PaywallFlow)
  Views/ (screen composition)
  Utilities/ (extensions + observability)
  PreviewSupport/ (deterministic preview fixtures)

App TemplateTests/
Config/xcconfigs/
project.yml
Makefile
scripts/
```

## Configuration

Configuration is read in this order:

1. process environment variables
2. generated Info.plist keys from xcconfigs
3. code fallback defaults

Relevant keys:

- `APP_ENV`
- `API_URL`
- `GITHUB_TOKEN`
- `ANALYTICS_PROVIDER` (`noop`, `console`, `firebase`)

See `App Template/.env.example` and `Config/xcconfigs/*.xcconfig`.

## Design Direction

This template intentionally leans into a liquid-glass look:

- layered translucency and gradient lighting
- soft neon accent glows
- subtle motion with `Reduce Motion` handling
- reusable visual primitives instead of one-off styling

Start with:

- `App Template/Design/Theme.swift`
- `App Template/Design/Components.swift`

## Documentation Map

- Quick setup: [QUICK_START.md](QUICK_START.md)
- iOS module dev guide: [App Template/README.md](App%20Template/README.md)
- Architecture deep dive: [App Template/ARCHITECTURE.md](App%20Template/ARCHITECTURE.md)
- Extension playbook: [EXTENDING_TEMPLATE.md](EXTENDING_TEMPLATE.md)
- Migration notes: [MIGRATION_NOTES.md](MIGRATION_NOTES.md)
- Firebase setup: [FIREBASE_SETUP.md](FIREBASE_SETUP.md)

## Backend Template

`Server Template/` includes an Express + PostgreSQL starter. Wire its base URL into `API_URL` and keep iOS services thin/typed.

Server docs:
- [Server Template/README.md](Server%20Template/README.md)
- [Server Template/INSTRUCTIONS.md](Server%20Template/INSTRUCTIONS.md)
