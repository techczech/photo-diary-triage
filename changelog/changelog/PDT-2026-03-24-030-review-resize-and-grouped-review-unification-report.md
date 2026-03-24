# PDT-2026-03-24-030 Review Resize And Grouped Review Unification Report

## Summary Of What Changed

- Fixed review-grid resizing so it now reflows against the last measured pane width instead of recalculating against zero and collapsing into a broken single strip.
- Made review-card thumbnails scale proportionally with the card width so card and image sizing stay in sync during resize and reset.
- Split compare controls into layout density and image zoom, then replaced the single-row compare strip with a responsive compare grid that can show more items at once.
- Kept compare as a full-window surface and reset compare layout density cleanly when compare closes.
- Changed the day-level “Sections” path into a grouped review surface that renders the same working review cards, uses the same selection and keyboard handlers, and keeps grouping plus expand/collapse controls.
- Added regression coverage for the measured-width resize fix, compare density metrics, and grouped-review interaction ordering.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserModels.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/InlineSectionOrganizer.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-030-review-resize-and-grouped-review-unification.md`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- Grouped review now shares the main review interactions, but it still renders as grouped sections rather than a single flat grid with section headers.
- List mode in grouped review is functional but remains secondary to the grid workflow.

## Shipped Release

- Version: `0.1.32`
- Feature slug: `review-resize-and-grouped-review-unification`
