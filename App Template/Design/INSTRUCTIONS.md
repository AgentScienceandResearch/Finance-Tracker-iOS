# Design Folder - Coding Assistant Instructions

## Purpose
`Design/` contains visual tokens and reusable liquid-glass UI primitives.

## Current Files
- `Theme.swift`
- `Components.swift`

## Rules
- Prefer `AppTheme`, `Typography`, `Spacing`, and `Radius` tokens over hardcoded values.
- Reuse design primitives before creating one-off style blocks.
- Keep the visual language coherent with the liquid-glass direction.
- Keep animation intensity subtle and performant.

## Accessibility
- Respect `Reduce Motion` for animated effects.
- Keep contrast readable on translucent backgrounds.
- Do not rely on color alone for meaning.

## Performance
- Be selective with blur/shadow stacks.
- Bound particle counts and animation refresh work.
