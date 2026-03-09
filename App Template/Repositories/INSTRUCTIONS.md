# Repositories Folder - Coding Assistant Instructions

## Purpose
Repositories isolate data-source specifics from manager-level business workflows.

## Current Files
- `UserRepository.swift` (`UserRepositorying`)
- `SubscriptionRepository.swift` (`SubscriptionRepositorying`)

## Rules
- Depend on protocols in managers; keep concrete repository details internal.
- Keep repository APIs focused and composable.
- Avoid UI state in repositories.
- Keep StoreKit/Firebase/network surface area out of view models and views.

## Testing Guidance
- Mock repository protocols in manager tests.
- Keep repository contracts stable; if changed, update manager tests in the same change.

## Error Guidance
- Throw typed/meaningful errors where possible.
- Let managers decide user-facing messaging.
