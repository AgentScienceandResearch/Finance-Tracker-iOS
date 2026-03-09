# Extending the Template

This playbook is for adding features while preserving architecture quality.

## 1) Add a Feature Vertically

Use this order:

1. `Models/` (data shape)
2. `Services/` or `Repositories/` (boundary)
3. `Managers/` (domain workflow)
4. `ViewModels/` (UI orchestration)
5. `Views/` (presentation)
6. tests + previews

## 2) Define Protocol Boundaries Early

Before writing concrete implementations, define interfaces that your view model or manager depends on.

Examples:

- `FeatureManaging`
- `FeatureRepositorying`
- `FeatureServing`

This keeps test stubs simple and avoids concrete singletons leaking into UI logic.

## 3) Wire Dependencies in `AppEnvironment`

If new runtime services/managers are needed:

- add concrete instance creation in `AppEnvironment`
- inject protocols into managers/view models
- avoid creating new singletons by default

## 4) Build UI with Design Tokens

Prefer existing primitives from `Design/`:

- `GlassCard`, `FloatingGlassCard`, `HazyOverlayCard`, `GlowingBorderCard`
- `GlassButton`, `AnimatedGlassButton`, chips/orbs
- `AppTheme`, `Typography`, `Spacing`, `Radius`

Add new components only when composition is no longer sufficient.

## 5) Accessibility and Motion Checklist

For each new screen/component:

- respect `Reduce Motion`
- add labels/hints for icon-only controls
- verify contrast on translucent surfaces
- verify dynamic type behavior

## 6) Testing Checklist

For each feature, add tests in `App TemplateTests/`:

- happy-path flow
- validation failures
- service/repository error propagation
- state reset/cleanup behavior

Optional: add smoke rendering test if feature introduces a complex view tree.

## 7) Config and Secrets

- put runtime values behind `AppConfig`
- never hardcode API secrets
- use `.xcconfig` + environment overrides

## 8) Observability

Track important business events through `AnalyticsTracking` and log failure paths via `Logging`.

Keep event naming stable and explicit.
