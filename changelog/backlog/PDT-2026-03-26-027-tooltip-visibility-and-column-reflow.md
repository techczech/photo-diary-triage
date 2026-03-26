# PDT-2026-03-26-027 Tooltip Visibility And Column Reflow

- Item ID: `PDT-2026-03-26-027`
- Title: `Tooltip visibility and column reflow`
- Current status: `implemented_pending_review`
- Target release version: `0.1.65`
- Target feature slug: `tooltip-visibility-and-column-reflow`

## User Request Summary

The hover tooltips are effectively hidden: they appear too late, do not show enough, and interfere with clicking. The user also reports that changing to a two-column layout no longer causes the view to auto-resize or reflow in the way it did before, so that behavior needs to be investigated next.

## Constraints

- Keep the current compact review/compare design.
- Improve tooltip usefulness without making them interfere with clicking.
- Preserve keyboard-first workflows.
- Do not reintroduce layout jitter or full-window resize lag.

## Implementation Intent

- Investigate the current hover-hint behavior and reduce or remove any delay that makes the hints feel hidden.
- Ensure the tooltip presentation is readable without blocking normal pointer interaction.
- Investigate the column-based layout behavior and restore the expected auto-fit/reflow when switching to two columns or other explicit column counts.
- Keep the current sidebar and review performance improvements intact.

## Test Conditions

- `swift build`
- `swift test`
- Manual validation:
  - hover hints appear quickly enough to be useful
  - hover hints do not block clicking on nearby controls
  - switching to two columns reflows the view as expected
  - fullscreen behavior still follows the column selection

## Success Criteria

- Hover hints are visible, timely, and non-intrusive.
- Explicit column changes immediately reflow the content in a predictable way.
- The change does not regress sidebar responsiveness, compare behavior, or keyboard navigation.
