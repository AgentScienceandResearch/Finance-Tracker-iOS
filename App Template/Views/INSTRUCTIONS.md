# Views Folder - Coding Assistant Instructions

## Purpose
`Views/` renders presentation state and forwards user actions to flow view models or injected handlers.

## Current Architecture
- Auth UI is orchestrated by `AuthenticationFlowViewModel`.
- Paywall UI is orchestrated by `PaywallFlowViewModel`.
- Production wiring comes from `AppEnvironment` (`App.swift`).
- Previews use deterministic fixtures in `PreviewSupport/`.

## Rules
- Keep views presentation-focused.
- Do not call repositories/services directly from views.
- Prefer injected dependencies over creating singletons inside view code.
- Keep icon-only controls accessible with labels/hints.
- Use `Task {}` for async user actions.
- Route UI instrumentation via abstractions (`EnvironmentValues.analyticsTracker`, `HapticFeedback`) instead of SDK calls.

## Preview Guidance
- Cover success, loading, and error states when practical.
- Use explicit preview fixtures/mocks; avoid nondeterministic state.
