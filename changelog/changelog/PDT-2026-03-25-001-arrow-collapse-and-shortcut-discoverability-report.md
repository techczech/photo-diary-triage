# PDT-2026-03-25-001 Arrow Collapse And Shortcut Discoverability Report

## Summary Of What Changed

- Added a real grouped-section keyboard target so plain arrow keys now operate on section headers once a group is focused: up and down move between groups, left collapses, and right expands.
- Centralized review-arrow handling inside `AppState` so the grouped-section and item-navigation paths are testable and consistent.
- Rebuilt the keyboard shortcuts sheet as a scrollable, grouped reference with stronger shortcut styling and better readability.
- Added hover help that exposes shortcut hints across the main review, grouped review, compare, preview, and import controls.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-25-001-arrow-collapse-and-shortcut-discoverability.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- Shortcut discoverability is now much better on the main review surfaces, but deeper metadata panels and some lower-frequency controls still have room for more tooltip coverage if needed.
- This slice improves the shortcuts reference and hover help, but it does not yet add a dedicated always-visible shortcut legend to the main window chrome.

## Shipped Release

- Version: `0.1.40`
- Feature slug: `arrow-collapse-and-shortcut-discoverability`
