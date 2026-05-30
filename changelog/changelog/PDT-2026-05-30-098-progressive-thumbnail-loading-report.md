# PDT-2026-05-30-098 progressive thumbnail loading — report

item_id: PDT-2026-05-30-098
shipped_release_version: 0.2.53
shipped_feature_slug: progressive-thumbnail-loading
status: implemented_pending_review

## Summary Of What Changed

Thumbnail loading now behaves like visible-first work instead of a whole-folder burst.

- Added a dedicated thumbnail loading state and review top-bar indicator: loaded/total, recent thumbnails per second, failed count, active count, and queued count in the help text.
- Changed bulk thumbnail scheduling so the app prioritizes the first/nearby review pages instead of treating every item in the selected folder as equally visible.
- Promoted queued background thumbnail work to visible priority when a cell actually appears, and reset stale scheduler work when the review thumbnail scope changes.
- Kept thumbnails progressive at the cell level: each completed thumbnail still updates its own `ThumbnailSlot`, independent of review snapshot refresh.
- Switched standard image thumbnail generation to ImageIO first, using requested max pixel size and eager decode, then falling back to Quick Look for formats ImageIO cannot thumbnail.
- Wrote thumbnail cache files through a temp file before moving into place, so partial writes are not treated as valid cached thumbnails.
- Made corrupt cached thumbnail decode failures visible as retry states and made retry regenerate the cached thumbnail instead of repeatedly decoding the same bad file.
- Stopped automatic retry loops when a failed thumbnail surface appears; the retry button now owns retry.
- Prevented ordinary successful thumbnail completions from mutating `thumbnailFailures` and forcing full review refreshes.
- Prevented no-cache thumbnail failures from overwriting more important import workflow status messages.
- Hardened headless tests by guarding `NSApp` itself before reading `keyWindow`.

## Analysis Notes

Current code already had per-cell `ThumbnailSlot` publishing, so the main progressive-loading bug was upstream: request and scheduling policy. `requestVisibleThumbnails` used `visibleMediaItems`, which means every item in the selected review context, not every on-screen cell. Large folders therefore filled the high-priority queue with too much work before the real viewport could dominate.

Apple guidance supported two implementation choices:

- Quick Look Thumbnailing remains a good fallback for common files and RAW-ish cases because it supports many common file types.
- ImageIO is appropriate for ordinary image thumbnails when the app can request `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`, orientation transform, and eager decode.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift` — visible-first thumbnail batching, progress tracking, retry regeneration, corrupt-cache handling, scheduler reset, status-message gating, headless `NSApp` guard.
- `Sources/PhotoDiaryTriage/PreviewStore.swift` — ImageIO-first thumbnail generation, direct `CGImage` cache write, temp-file cache writes, Quick Look fallback.
- `Sources/PhotoDiaryTriage/ThumbnailScheduler.swift` — queued background promotion and reset support.
- `Sources/PhotoDiaryTriage/UIState.swift` — `ThumbnailLoadingSnapshot` and `ThumbnailLoadingState`.
- `Sources/PhotoDiaryTriage/ContentView.swift` and `ContentViewBrowserSections.swift` — thumbnail loading state wiring and compact review top-bar indicator.
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift` — failed thumbnails no longer auto-retry on appear.
- `Tests/PhotoDiaryTriageTests/ThumbnailSchedulerTests.swift` — regression tests for promotion and reset.
- `APP_RELEASE.env` — `0.2.53` / build `130` / `progressive-thumbnail-loading`.

## Verification

- `swift build` — passed.
- `swift test --filter ThumbnailSchedulerTests` — passed 4 tests.
- `swift test` — passed 159 tests.
- `git diff --check` — passed.

## Known Gaps Or Follow-up Items

- Manual verification still needed with a large real photo folder: confirm first thumbnails appear quickly, cells fill progressively, the top-bar indicator moves steadily, retry appears only for real failures, and scrolling promotes newly visible cells.
- Future optional pass: use Quick Look `generateRepresentations` for a low-quality-first placeholder path if real RAW folders still feel slow after this visible-first/ImageIO pass.

## Handoff — Please Test APP_VERSION 0.2.53

Intended user-visible behavior in `APP_VERSION=0.2.53`: opening a large review folder should show a compact `Thumbs loaded/total speed` indicator in the review top bar, load the first/nearby thumbnails before off-screen bulk work, fill cells progressively as each thumbnail finishes, and keep retry for real failures without retry taking over slow-but-active loads.

Please test `APP_VERSION 0.2.53`.
