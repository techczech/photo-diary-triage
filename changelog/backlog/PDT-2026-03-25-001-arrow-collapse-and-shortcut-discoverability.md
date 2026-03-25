# PDT-2026-03-25-001 Arrow Collapse And Shortcut Discoverability

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.40`
- Target feature slug: `arrow-collapse-and-shortcut-discoverability`

## User Request

Grouped review now performs well, but keyboard behavior and shortcut discoverability are still incomplete. When a grouped-section header is the active target, plain left and right arrows should collapse and expand it while up and down move between sections. The keyboard shortcuts sheet is hard to read and does not scroll, and the UI needs hover help that exposes the main shortcuts directly on controls.

## Constraints

- Preserve the responsiveness restored in `0.1.37`.
- Preserve the grouped review and compare behavior already working in `0.1.39`.
- Do not regress plain arrow-key item navigation when the review grid itself is the active target.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Add an explicit grouped-section keyboard target so plain arrow keys operate on section headers once a section is focused.
- Keep item navigation as the default when media items are focused, and allow section-focused navigation to move between groups with up and down while collapsing or expanding with left and right.
- Rebuild the keyboard shortcuts sheet as a scrollable, grouped, higher-contrast reference.
- Add tooltip help that includes shortcut hints on the main review and grouped-review controls.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Section-focused arrow navigation uses plain left and right for collapse and expand.
- The shortcuts sheet scrolls and remains readable with all shortcut groups visible.
- Main review controls expose shortcut hints through UI help text.

## Success Criteria

- Grouped-section keyboard navigation works without needing modifier keys once a section header is selected.
- Users can read the full keyboard shortcuts reference without clipped content.
- Shortcut discoverability improves directly in the UI through hover help.
