# PDT-2026-05-27-078 crop history and version switching report

item_id: PDT-2026-05-27-078
status: implemented
shipped_release_version: 0.2.35
shipped_feature_slug: crop-history-version-switching

## Summary

Implemented in-app crop history and version switching.

User-visible behavior in `APP_VERSION=0.2.35`:

- The Selected Photo inspector now shows a `Crop Versions` section for an original with crops or for any selected crop.
- The version list shows the original first, followed by each known crop output.
- The currently selected version is marked `Current`.
- Crop/original versions that are loaded in the current browser view can be opened from the inspector with the arrow button.
- Opening a version switches preview, focus, selection, and review scroll target inside the app.
- Known crop versions that are not loaded are still listed as `Not loaded`, but their switch button is disabled.
- Finder reveal is no longer the primary way to navigate between original and cropped versions.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-27-078-crop-history-and-version-switching.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build`: passed.
- `./scripts/build_app_bundle.sh`: built `dist/PhotoDiaryTriage.app`.
- bundle metadata checked:
  - `CFBundleShortVersionString`: `0.2.35`
  - `CFBundleVersion`: `112`
  - `PDTLatestFeatureSlug`: `crop-history-version-switching`
- `git diff --check`: passed.

## Blocked Verification

- `swift test --filter inspectorCropHistoryShowsVersionsAndSwitchesInApp`: blocked before test compilation because active Command Line Tools cannot provide XCTest platform paths.
- Current toolchain path: `/Library/Developer/CommandLineTools`.
- Error: `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`; SwiftPM then reports `XCTest not available`.

## Known Gaps

- Manual real-photo verification is still needed to confirm that the inspector version list feels right with several crops.
- Finder reveal for crop files remains lower priority and is not implemented in this change.
