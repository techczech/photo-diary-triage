# PDT-2026-03-24-030 Review Resize And Grouped Review Unification

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.32`
- Target feature slug: `review-resize-and-grouped-review-unification`

## User Request

The current review grid and compare sizing controls are still broken in real use. Review resizing can collapse into a bad single-strip layout and reset incorrectly. Compare resizing changes only image zoom, not layout density. The separate Sections mode is also still functionally weaker than the review grid and should be turned into a grouped review surface with the same working interactions.

## Constraints

- Preserve the current speed gains from `0.1.31`.
- Keep keyboard-first review behavior intact while fixing layout controls.
- Compare must remain a full-window review surface.
- Grouped review must support the same core actions as flat review.
- Release handoff must name the exact version to test and ask for testing.

## Implementation Intent

- Fix review-grid resizing to use the last measured pane width instead of recalculating with a zero width.
- Make review cards resize proportionally so container size and thumbnail presentation stay in sync.
- Split compare controls into layout density and image zoom, and reflow compare into a real responsive grid instead of a single horizontal strip.
- Replace the weak standalone Sections mode with a unified grouped review mode that uses the same review cards, selection, keyboard, preview, compare, and import actions as flat review.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Review `+ / - / 0` reflows immediately without requiring a view toggle.
- Compare can show more items by changing layout density, independently from image zoom.
- Grouped review supports the same selection and shortcut behavior as flat review.

## Success Criteria

- Review sizing works predictably in both directions and on reset.
- Compare has separate working controls for layout density and image zoom.
- Grouped review becomes a real working review surface instead of a reduced navigation-only mode.
