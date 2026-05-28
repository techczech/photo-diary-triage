# PDT-2026-05-27-080 crop geometry correctness report

item_id: PDT-2026-05-27-080
status: implemented
shipped_release_version: 0.2.36
shipped_feature_slug: crop-geometry-correctness

## Summary

Fixed the crop geometry path so `Crop Visible` and `Drag Crop` use a shared coordinate mapper and the visible crop rectangle is updated when the image viewport changes.

User-visible behavior in `APP_VERSION=0.2.36`:

- Panning or scrolling the preview updates the crop rectangle used by `Crop Visible`.
- Crop coordinate conversion is no longer hidden inside the AppKit view.
- A zoomed image shows a dashed visible-crop boundary, making the cropable visible area clearer.
- Manual drag crop uses the same normalized coordinate contract as visible crop.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/CropGeometry.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `changelog/backlog/PDT-2026-05-27-080-crop-geometry-correctness.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build`: passed.
- `git diff --check`: passed.

## Blocked Verification

- `swift test --filter Crop`: blocked before test compilation because active Command Line Tools cannot provide XCTest platform paths.
- Current toolchain path remains `/Library/Developer/CommandLineTools`.
- Error: SwiftPM reports `XCTest not available` after `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`.

## Known Gaps

- The new crop geometry tests are written but cannot run on this machine until the XCTest/toolchain issue is fixed.
- Rotated-image crop verification still needs either an automated fixture or manual validation.
- Crop link grouping, drag affordances, mouse zoom/pan, and performance pass are tracked separately in `PDT-2026-05-27-081` through `PDT-2026-05-28-084`.
