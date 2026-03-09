# Managers Folder - Coding Assistant Instructions

## Purpose
Managers own domain workflows and publish app state for feature areas.

## Current Architecture
- `AuthenticationManager` implements `AuthenticationManaging`.
- `SubscriptionManager` implements `SubscriptionManaging`.
- `DatabaseManager` implements `UserStoring` with Firebase + in-memory fallback.
- Managers use repositories/abstractions where available.

## Rules
- Keep managers `@MainActor` and `ObservableObject`.
- Keep user-facing error messages clear and actionable.
- Keep long-running operations async and loading state consistent.
- Use observability abstractions (`Logging`, `AnalyticsTracking`) for key events/failures.

## Dependency Guidance
- Prefer protocol dependencies in initializers.
- Keep singleton usage intentional (`shared` only when global lifecycle is required).
- When public APIs change, update protocol + call sites + tests together.
