# PDT-2026-03-24-035 Grouped Review Performance Regression Fix Report

## Summary Of What Changed

- Cached inline day sections and organized inline sections in `AppState` instead of recomputing them across repeated SwiftUI body updates.
- Added explicit cache invalidation on the state changes that actually affect grouped-review structure: selected review node, archive media loads, browser cache rebuilds, and organization mode changes.
- Preserved grouped review availability from visible media while removing the repeated synthetic-section hot path that caused the lag regression.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-035-grouped-review-performance-regression-fix.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- This restores the derived-state caching path for grouped review, but it is not a formal performance benchmark. Real-session validation is still needed.

## Shipped Release

- Version: `0.1.37`
- Feature slug: `grouped-review-performance-regression-fix`
