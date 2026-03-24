# PDT-2026-03-24-036 Keyboard Navigation And Command Coverage Report

## Summary Of What Changed

- Added command-key shortcuts for switching between sidebar and review focus, flat and grouped review, grid and list layouts, grouped-review organization modes, grouped expand/collapse actions, inspector toggling, and the main import workflow actions.
- Made `Open` from the keyboard jump from sidebar selection into the active review surface and open the focused item when already in review.
- Added grouped-section keyboard focus state, visual focus highlighting, scroll-to-section behavior, and keyboard expand/collapse navigation for grouped review.
- Extended the keyboard help panel to document the new focus, grouping, layout, and import shortcuts.
- Added regression tests for sidebar-to-review keyboard flow and grouped-section keyboard navigation.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-036-keyboard-navigation-and-command-coverage.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- This adds command shortcuts and grouped-section keyboard control, but it does not yet make the sidebar list itself a custom first-responder surface.

## Shipped Release

- Version: `0.1.38`
- Feature slug: `keyboard-navigation-and-command-coverage`
