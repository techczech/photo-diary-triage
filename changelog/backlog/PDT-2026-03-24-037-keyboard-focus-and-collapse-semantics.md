# PDT-2026-03-24-037 Keyboard Focus And Collapse Semantics

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.39`
- Target feature slug: `keyboard-focus-and-collapse-semantics`

## User Request

The recent keyboard coverage work still misses key behavior details. `Cmd-1` does not move keyboard focus into the sidebar list, arrow navigation in review does not keep the focused image scrolled into view, and grouped-section collapse behavior is inconsistent because some visible groups are not actually collapsible.

## Constraints

- Preserve the restored responsiveness from `0.1.37`.
- Preserve the shortcut coverage from `0.1.38`.
- Fix keyboard semantics without reintroducing the lag that came from repeated grouped-review recomputation.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Make sidebar focus commands move the real first responder to the sidebar list instead of only updating app state.
- Auto-scroll the review surface to keep the focused image visible during keyboard navigation.
- Make grouped review use a consistent collapse model where every visible group can collapse its own contents.
- Add regression coverage for keyboard review autoscroll state and grouped collapse semantics.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- `Cmd-1` moves real keyboard focus to the sidebar navigation surface.
- Arrow-key review navigation keeps the focused item visible in the active review view.
- Visible grouped sections can be collapsed and expanded consistently.

## Success Criteria

- Keyboard shortcuts operate on the intended surface, not just on internal state.
- Review navigation feels like true keyboard browsing because focus stays visible.
- Grouped review collapse behavior is predictable across all visible groups.
