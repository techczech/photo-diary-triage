# PDT-2026-03-24-036 Keyboard Navigation And Command Coverage

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.38`
- Target feature slug: `keyboard-navigation-and-command-coverage`

## User Request

Keyboard-first triage is still incomplete. The user can navigate the review grid, but cannot efficiently jump from the sidebar into the grid, switch between flat and grouped review, expand or collapse grouped sections by keyboard, or trigger many important UI actions without reaching for the mouse. Buttons and common view switches need proper keyboard shortcuts, and grouped review sections need keyboard expansion and navigation.

## Constraints

- Preserve the restored review responsiveness from `0.1.37`.
- Preserve existing single-key review actions that already work in the active review surface.
- Add keyboard shortcuts without leaking them into forms, sheets, or unrelated controls.
- Keep grouped review and flat review behavior aligned where possible.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Add command-key shortcuts for view/layout actions such as switching flat/grouped review, switching grid/list, opening compare, opening preview, expanding/collapsing grouped sections, and toggling left/right side panels where supported.
- Add an explicit keyboard path from sidebar or grouped section navigation into the active review grid.
- Add keyboard navigation and expand/collapse behavior for grouped review sections so the user can work those structures without the mouse.
- Centralize these actions in `AppState`/commands rather than wiring ad hoc button-only handlers.
- Add regression coverage for grouped-review keyboard actions and command availability helpers.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- The user can jump from sidebar navigation into the review grid without using the mouse.
- Grouped review sections can be expanded/collapsed and navigated by keyboard.
- Major toolbar/button actions have matching keyboard shortcuts.

## Success Criteria

- Sidebar, grouped review, and main review grid can be driven quickly from the keyboard.
- Flat/grouped review switching and common view/layout actions no longer require the mouse.
- Expand/collapse operations in grouped review are keyboard-accessible and predictable.
