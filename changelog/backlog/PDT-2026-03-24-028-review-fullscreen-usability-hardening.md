# PDT-2026-03-24-028 Review Fullscreen Usability Hardening

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.30`
- Target feature slug: `review-fullscreen-usability-hardening`

## User Request

Fix the remaining real-world review failures: overlapping grid cards, brittle resizing/full-screen behavior, weak compare layout, missing obvious sizing controls, unreliable preview/keyboard flow, and the inline mini-preview default getting in the way of actual triage.

## Constraints

- Do not optimize for the tiny inline previews over the main review grid.
- The main review surface must remain usable in full-screen.
- Compare must scale to available space and stay useful for two or more selected items.
- Keyboard-first triage remains mandatory.
- Speed and usability take priority over cleanup or refactor work.

## Implementation Intent

- Replace the remaining adaptive grid behavior with explicit column generation based on measured width and current card size.
- Make the day-level browser default to a proper review grid, with inline sections available as a secondary mode instead of the default surface.
- Compress and stabilize the review toolbar so sizing controls remain visible and useful at different window widths.
- Make the compare sheet expand with available full-screen space.
- Harden click handling for first-click activation and re-verify preview/open behavior.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- The review grid no longer overlaps when resizing or changing sidebar/full-screen state.
- The compare sheet uses substantially more available width in full-screen.

## Success Criteria

- The primary review surface is a stable, usable grid rather than tiny section previews.
- Grid sizing survives full-screen and sidebar changes without overlapping cards.
- Compare is clearly usable for large side-by-side inspection.
