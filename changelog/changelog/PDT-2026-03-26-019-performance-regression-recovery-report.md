# PDT-2026-03-26-019 Performance Regression Recovery Report

- Item ID: `PDT-2026-03-26-019`
- Shipped release version: `0.1.57`
- Shipped feature slug: `performance-regression-recovery`

## Summary Of What Changed

- Removed the remaining animated review and grouped-review scroll transitions so focus and selection jumps are immediate.
- Moved thumbnail decoding out of the SwiftUI render path and into an async shared decode pipeline.
- Reused the same decode pipeline for preview and compare so full-size images are no longer synchronously loaded in view updates.
- Kept the existing review and compare behavior intact while restoring a cache-first image loading path.

## Files Changed

- `Sources/PhotoDiaryTriage/DecodedImagePipeline.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- The grouped-review `Escape` behavior is still a known follow-up area from earlier feedback and is not fully resolved by this slice.
- This release removes the obvious synchronous image decode regressions, but real-world validation on large sessions is still required to confirm that the earlier instant-feel performance is back.

