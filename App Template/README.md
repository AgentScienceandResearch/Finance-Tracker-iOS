# App Module Guide

This folder contains the iOS application source for `TemplateApp`.

## Architectural Shape

- UI layer: `Views/`
- UI orchestration: `ViewModels/`
- Domain state/workflows: `Managers/`
- Boundary adapters: `Repositories/`
- External integrations: `Services/`
- Shared primitives: `Design/`, `Utilities/`, `Models/`
- Composition root: `AppEnvironment.swift`

Primary flow:

`View -> FlowViewModel -> Manager -> Repository/Service -> System/API`

## Dependency Injection

`AppEnvironment` constructs runtime dependencies once and injects them into production entry points.

Key runtime objects:

- `AppConfig`
- `AppLogger` (`Logging`)
- `NoOpAnalyticsTracker` (`AnalyticsTracking`)
- `DatabaseManager`
- `AuthenticationManager`
- `SubscriptionManager`
- `APIService`
- `GitHubService`

## Design System

Use tokens/components from `Design/` before adding custom styles.

- Tokens: `AppTheme`, `Typography`, `Spacing`, `Radius`
- Effects: gradient background, glass cards, glowing borders, chips, orb buttons
- Accessibility: honor `Reduce Motion` and readable contrast on translucent surfaces

## Testing

`App TemplateTests/` covers:

- manager behavior with protocol-based stubs
- flow view-model validation and orchestration
- database fallback/query behavior
- snapshot smoke rendering for key views

Run:

```bash
make test
```

## Folder Instructions

Each major folder includes a local `INSTRUCTIONS.md` with implementation rules.

- `Design/INSTRUCTIONS.md`
- `Views/INSTRUCTIONS.md`
- `ViewModels/INSTRUCTIONS.md`
- `Managers/INSTRUCTIONS.md`
- `Services/INSTRUCTIONS.md`
- `Models/INSTRUCTIONS.md`
- `Utilities/INSTRUCTIONS.md`
- `Repositories/INSTRUCTIONS.md`
- `Config/INSTRUCTIONS.md`
- `PreviewSupport/INSTRUCTIONS.md`
