# ViewModels Folder - Coding Assistant Instructions

## Purpose
Flow view models own UI-facing state and control flow.

## Current Files
- `AuthenticationFlowViewModel.swift`
- `PaywallFlowViewModel.swift`

## Rules
- Use `@MainActor final class` + `ObservableObject`.
- Keep validation and orchestration logic in view models, not views.
- Depend on protocols (`AuthenticationManaging`, `SubscriptionManaging`).
- Expose user-facing state via `@Published`.

## Testing
- Mock manager protocols.
- Cover validation failures, success paths, and dependency errors.
