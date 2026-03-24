# PDT-2026-03-24-037 Keyboard Focus And Collapse Semantics Report

## Summary Of What Changed

- Made sidebar focus commands target the real sidebar outline/table first responder instead of only flipping internal pane state.
- Added review-item autoscroll state so keyboard navigation requests keep the focused photo scrolled into view.
- Changed grouped-review collapse semantics so every visible group can collapse its own contents, not only parent sections with child nodes.
- Updated grouped review to default sections to expanded, then rely on consistent collapse state for both parent and leaf groups.
- Added regression coverage for review autoscroll state and leaf-group collapse behavior.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/InlineSectionOrganizer.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-037-keyboard-focus-and-collapse-semantics.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- The sidebar first-responder fix is verified indirectly through the app behavior and not through an automated UI test.

## Shipped Release

- Version: `0.1.39`
- Feature slug: `keyboard-focus-and-collapse-semantics`
