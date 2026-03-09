# Migration Notes

This file tracks key template changes introduced in the latest modernization pass.

## Snapshot Date

- March 7, 2026

## Major Changes

### Project and Build System

- Added XcodeGen spec: `project.yml`
- Added generated project/workspace entry points
- Added environment-specific xcconfigs under `Config/xcconfigs/`
- Added Makefile and bootstrap scripts for repeatable setup

### Runtime Configuration

- Added typed `AppConfig`
- Config keys now flow from xcconfig -> Info.plist -> runtime process env

### Architecture Refinement

- Added repository layer:
  - `UserRepositorying` / `UserRepository`
  - `SubscriptionRepositorying` / `StoreKitSubscriptionRepository`
- Managers now depend on repositories/protocols rather than direct low-level calls
- `AppEnvironment` now composes config + observability + managers/services

### Observability

- Added `Logging`, `AnalyticsTracking`, `AnalyticsEvent`
- Added `AppLogger` (OSLog) and `NoOpAnalyticsTracker`
- Integrated logging into API/auth/subscription/database flows

### UI/UX and Accessibility

- Liquid-glass components improved and normalized for current Swift initializer behavior
- Added reduced-motion handling to animated components
- Added accessibility labels/hints and dynamic type limits for key controls

### Testing

Added/expanded test coverage:

- `AuthenticationManagerTests`
- `FlowViewModelTests`
- `DatabaseManagerTests`
- `SubscriptionManagerTests`
- `ViewSnapshotSmokeTests`

Current baseline: 20 tests passing.

## Potential Follow-ups

- replace `NoOpAnalyticsTracker` with real analytics provider
- add UI test target for critical end-to-end paths
- move remaining one-off service patterns behind explicit protocols (where useful)
