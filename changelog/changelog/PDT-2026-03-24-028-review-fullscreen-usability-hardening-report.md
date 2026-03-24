# PDT-2026-03-24-028 Review Fullscreen Usability Hardening Report

## Summary Of What Changed

- Changed the day-level review flow so the default surface is now a real review grid instead of the tiny inline section previews; sections remain available as a secondary mode.
- Removed the remaining overlap-prone adaptive grid behavior and switched the review grid to explicit measured fixed columns that track the current card size and window width more predictably.
- Compressed the review toolbar with a responsive fallback so the sizing controls, open, compare, and actions remain usable at narrower widths.
- Expanded the compare sheet to use much more available width and height in full-screen, with card widths computed from the actual sheet size.
- Enabled first-click activation on custom grid click targets so preview/selection behavior works more reliably when activating the window.
- Added regression coverage for the new day-container review behavior.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserModels.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInlineViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-028-review-fullscreen-usability-hardening.md`

## Verification Performed

- `swift test`

## Known Gaps Or Follow-Up Items

- This fixes the major fullscreen/grid brittleness, but the broader speed work on archive tree caching and faster import throughput is still pending.
- The compare workflow still needs user judgement on whether the new fullscreen sizing is large enough for actual keep/reject decisions.

## Shipped Release

- Version: `0.1.30`
- Feature slug: `review-fullscreen-usability-hardening`
