# PreviewSupport Folder - Coding Assistant Instructions

## Purpose
PreviewSupport provides deterministic fixtures/mocks for SwiftUI previews and rendering smoke tests.

## Current Files
- `PreviewFixtures.swift`

## Rules
- Keep fixtures static and predictable.
- Cover at least success/loading/error states for key views.
- Avoid network/StoreKit/Firebase calls in previews.
- Prefer protocol-conforming preview mocks over ad hoc singletons.

## Maintenance
When production manager/view-model APIs change:
- update preview mocks immediately
- ensure `#Preview` blocks still compile
- keep fixture naming explicit (`...Loading`, `...Error`, `...Success`)
