# Config Folder - Coding Assistant Instructions

## Purpose
`Config/` contains runtime configuration loading and environment key handling.

## Current Files
- `AppConfig.swift`

## Rules
- Keep config loading deterministic and side-effect-light.
- Prefer typed config values over raw string lookups in app code.
- Add new keys in one place and document defaults.
- Do not hardcode secrets in source.
- Normalize provider-like keys into typed enums (`AnalyticsProvider`) at config boundary.

## Key Pattern
- Read runtime env first.
- Fallback to Info.plist values generated from xcconfig.
- Fallback to safe defaults as a last resort.

## Change Checklist
When adding a config key:
- Update `AppConfig`.
- Update `Config/xcconfigs/*.xcconfig`.
- Update `App Template/.env.example` if relevant.
- Update docs mentioning configuration.
