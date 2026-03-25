# PDT-2026-03-25-003 Grouped Enter Escape And Shortcut Chip Cleanup

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.42`
- Target feature slug: `grouped-enter-escape-and-shortcut-chip-cleanup`

## User Request

Grouped-section keyboard flow still needs a complete enter/escape model. Pressing Return on a focused section header should enter that section for item navigation, Escape from item navigation should return to grouped-section selection, and Cmd-Return should drill into the focused grouped section as its own scoped review context. The shortcut bubbles also need to show only the shortcut keys rather than long descriptions.

## Constraints

- Preserve the working grouped left-right and up-down navigation from `0.1.41`.
- Preserve the current performance of grouped review and the visible shortcut bubble layer.
- Keep normal Return behavior for focused review items outside grouped-section focus.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Add grouped-section enter and escape handling in `AppState` so section focus and item focus become explicit keyboard modes.
- Make Cmd-Return drill into the focused section as a scoped review set and make Escape climb back out to the section selector.
- Change shortcut bubbles to display only the key chord, while leaving full descriptions in help text or the keyboard sheet.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Pressing Return on a focused grouped section enters item navigation for that section.
- Pressing Escape from grouped item navigation returns to grouped-section focus.
- Pressing Cmd-Return on a focused grouped section opens that section as a scoped review set.
- Shortcut bubbles show only the key chords.

## Success Criteria

- Grouped review supports a fast keyboard-only loop for enter section, review items, and escape back to section selection.
- Scoped section drill-in works like opening a folder-level review from the keyboard.
- Shortcut bubbles are compact and show only the shortcut keys.
