# PDT-2026-03-24-032 Grouped Review Shell Visibility Fix Report

## Summary Of What Changed

- Restored a consistent review shell for all media-review contexts instead of routing some nodes directly around the grouped/flat review host.
- Added an explicit grouped-review availability guard so the grouped mode falls back cleanly when the current node cannot provide day-grouped sections.
- Added regression coverage for both supported and unsupported grouped-review contexts.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-032-grouped-review-shell-visibility-fix.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- This fixes grouped-review visibility and fallback behavior only. It does not change compare, zoom, or performance behavior.

## Shipped Release

- Version: `0.1.34`
- Feature slug: `grouped-review-shell-visibility-fix`
