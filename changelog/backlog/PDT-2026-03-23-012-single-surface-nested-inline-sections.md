# PDT-2026-03-23-012 Single Surface Nested Inline Sections

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.10`
- Target feature slug: `nested-inline-sections`

## User Request

Fix the grouped review surface so it becomes a single nested grid instead of a flat grid with additive grouped sections appended underneath.

## Constraints

- Grouped mode must replace the flat grid entirely instead of duplicating photos across parent and child sections.
- Supported structures are:
  - `Day -> Photos`
  - `Day -> Burst -> Photos`
  - `Day -> Cluster -> Photos`
  - `Day -> Cluster -> Burst -> Photos`
- Multiple days start collapsed, a single day auto-expands, and nested cluster/burst sections start collapsed.
- `Expand All` and `Collapse All` must affect every visible level in the active grouping mode.

## Implementation Intent

- Replace the additive inline-browser layout with a single nested review surface.
- Remove synthetic `Photos`, `Bursts`, and `Time Clusters` review rows from the grouped surface.
- Ensure preview-strip clicks expand the relevant section path and reveal the photo in the main grouped grid.
- Reset expansion state when the grouping mode changes.

## Test Conditions

- Grouped mode no longer shows a flat photo grid above nested sections.
- Photos appear only in the deepest active section and are not duplicated in parent sections.
- Preview strips remain visible on collapsed sections and clicking a preview expands the relevant section.
- Switching grouping modes resets expansion state to the default for that mode.

## Success Criteria

- The review area behaves as one nested, collapsible grid surface.
