# PDT-2026-03-26-025 Compact Review And Compare Action Row

- Item ID: `PDT-2026-03-26-025`
- Title: `Compact review and compare action row`
- Current status: `approved_for_implementation`
- Target release version: `0.1.63`
- Target feature slug: `compact-review-and-compare-action-row`

## User Request Summary

The user wants the review and compare cards to use less vertical space. The S / X triage buttons and the RAW toggle should move onto the same row as the date and metadata label, and the RAW control should be reduced to a small `R` control instead of taking up a larger toggle footprint. The `RAW` state should still be visible in the pill label when enabled.

## Constraints

- Preserve the existing keyboard shortcuts and triage behavior.
- Keep the review and compare surfaces fast.
- Do not add animations or transitions.
- Keep the metadata pill informative without reintroducing tall card chrome.

## Implementation Intent

- Move the small triage controls into the metadata row on review cards and compare cards.
- Replace the larger RAW toggle presentation with a compact `R` control.
- Keep the selected/excluded/undecided pill and the `RAW` indicator visible in the metadata summary.
- Reduce the total card height in both review and compare without changing the underlying triage state model.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - review grid cards show a compact metadata row with S / X / D / R controls inline
  - compare cards use the same compact inline control row
  - RAW still appears in the metadata pill when enabled
  - keyboard shortcuts continue to work unchanged

## Success Criteria

- The review and compare cards consume less vertical space.
- The RAW control is compact and visually consistent with the other triage buttons.
- The `RAW` state is still visible in the card metadata when relevant.
- No regressions in keyboard triage or compare behavior.
