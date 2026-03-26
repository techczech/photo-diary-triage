# PDT-2026-03-26-024 Compare Focus And Arrow Navigation

- Item ID: `PDT-2026-03-26-024`
- Title: `Compare focus and arrow navigation`
- Current status: `approved_for_implementation`
- Target release version: `0.1.62`
- Target feature slug: `compare-focus-and-arrow-navigation`

## User Request Summary

The compare pop-up is still opening in a bad default state. The user wants the compare sheet to open with only the first item focused/selected, not everything selected, and to be able to use the arrow keys immediately to move through compare items.

The user also noted that the current speed is acceptable for now, but performance work should remain a follow-up concern rather than being forgotten.

## Constraints

- Preserve the current compare layout and compare decision workflow.
- Do not regress the recent speed improvements.
- Keep the compare surface keyboard-first.
- No new animations or transitions.

## Implementation Intent

- Give compare its own focused-item state so the compare sheet can start on a single item instead of inheriting a multi-selected review state.
- Wire arrow keys in the compare sheet to move between compare items immediately when the sheet opens.
- Keep compare item borders and selection cues aligned with the compare focus state.
- Leave the current review-grid and sidebar behavior unchanged unless compare focus state needs a small shared helper.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - open compare from a multi-item selection
  - confirm only the first compare item starts focused
  - use arrow keys immediately inside compare
  - confirm the rest of compare remains usable for select/exclude/open actions

## Success Criteria

- Compare no longer opens with every item effectively selected.
- The first compare item is immediately focusable on open.
- Arrow keys move through compare items without extra mouse clicks.
- The recent speed improvements remain intact.
