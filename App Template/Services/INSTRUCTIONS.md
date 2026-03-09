# Services Folder - Coding Assistant Instructions

## Purpose
Services encapsulate transport and third-party integration concerns.

## Current Files
- `APIService.swift` (`APIServing`)
- `GitHubService.swift`

## Rules
- Keep service methods focused on request/response concerns.
- Do not embed business workflow logic in services.
- Surface typed/structured errors instead of silent failure.
- Keep auth/header/token handling localized to service boundaries.
- Read runtime values from config, not hardcoded literals.

## Testing Guidance
- Mock services at manager/view-model boundaries.
- Validate decode, non-2xx handling, and timeout/network failures.
