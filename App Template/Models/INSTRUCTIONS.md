# Models Folder - Coding Assistant Instructions

## Purpose
Models define shared data structures exchanged across layers.

## Current Models
- `User`
- `SubscriptionPlan`

## Rules
- Prefer `struct` value types.
- Keep models data-focused (no async/business workflow logic).
- Add protocol conformances deliberately (`Codable`, `Identifiable`, `Equatable`).
- Keep one primary model per file.

## Change Checklist
When model properties change:
- update dependent managers/services/view models
- update tests and preview fixtures
- validate encoding/decoding behavior when relevant
