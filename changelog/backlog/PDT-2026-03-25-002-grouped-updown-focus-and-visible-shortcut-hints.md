# PDT-2026-03-25-002 Grouped Up-Down Focus And Visible Shortcut Hints

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.41`
- Target feature slug: `grouped-updown-focus-and-visible-shortcut-hints`

## User Request

The grouped-section collapse behavior now works on left and right, but up and down still do not move between grouped sections after the header is selected. The shortcut reference sheet is improved, but discoverability in the main UI still fails because hover hints are not actually visible on the controls and review items.

## Constraints

- Preserve the responsiveness and grouped-review performance from `0.1.40`.
- Preserve the grouped-section left and right collapse behavior that already works.
- Do not regress normal item navigation when the review grid item target is active.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Fix review-key responder focus so grouped-section header selection reliably hands arrow-key control back to the review keyboard layer.
- Keep grouped-section up and down on plain arrows once a group header is focused.
- Replace fragile tooltip-only shortcut discoverability with visible in-app shortcut hints on the main review controls and review items, while keeping help text as a fallback.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- After clicking a grouped section header, plain up and down move between grouped sections.
- Main review controls and review items show visible shortcut hints in the app UI.

## Success Criteria

- Grouped-section keyboard navigation works for all four plain arrow directions after a group header is selected.
- Users can discover the main shortcuts directly from the review UI without needing the shortcuts sheet.
