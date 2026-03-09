# Utilities Folder - Coding Assistant Instructions

## Purpose
Utilities provide reusable cross-cutting helpers and abstractions.

## Current Scope
- Generic Swift/SwiftUI extensions (`Extensions.swift`)
- Observability abstractions and defaults (`Observability.swift`)
- Analytics provider adapters/factory (`AnalyticsProvider.swift`)
- Environment-level analytics injection (`EnvironmentValues.analyticsTracker`)
- Haptic helper utilities (`HapticFeedback`)

## Rules
- Keep utilities generic and low-side-effect.
- Avoid feature-specific business workflows here.
- Keep APIs small and predictable.
- Prefer extension-based helpers for native types.

## Observability Guidance
- Use `Logging` and `AnalyticsTracking` interfaces in app logic.
- Keep concrete SDK coupling behind adapter implementations.
