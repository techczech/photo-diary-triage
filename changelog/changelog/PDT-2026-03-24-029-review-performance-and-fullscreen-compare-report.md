# PDT-2026-03-24-029 Review Performance And Fullscreen Compare Report

## Summary Of What Changed

- Removed the most obvious review-grid hot paths by caching the browser tree, browser node map, session media lookup, per-node visible media lists, and per-item archive preview text instead of rebuilding them repeatedly during rendering.
- Added in-memory thumbnail reuse and missing-file tracking so the grid stops reopening the same thumbnail files from disk on every redraw.
- Changed review, inline, and inspector thumbnail surfaces to request thumbnails as they appear on screen rather than depending on repeated synchronous image loads.
- Tightened background thumbnail prefetching so visible items stay prioritized without trying to warm the entire session at once.
- Replaced the cramped compare popup behavior with a full-window compare takeover that fills the app window and scales card size from the available space.
- Disabled review-grid keyboard focus while compare is open so hidden shortcut handlers do not compete with the dedicated compare surface.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInlineViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-029-review-performance-and-fullscreen-compare.md`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- This removes several major self-inflicted render bottlenecks, but the requested “10x faster” target is not yet benchmarked.
- Archive tree invalidation/caching beyond the in-memory browser cache is still a follow-up item if large archive browsing remains slow.
- Import throughput is unchanged in this slice; this work only targets browsing and compare responsiveness.

## Shipped Release

- Version: `0.1.31`
- Feature slug: `review-performance-and-fullscreen-compare`
