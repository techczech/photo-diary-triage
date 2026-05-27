# PDT-2026-05-27-077 crop feedback and immediate preview report

item_id: PDT-2026-05-27-077
status: implemented
shipped_release_version: 0.2.34
shipped_feature_slug: crop-feedback-immediate-preview

## Summary

Fixed crop feedback and immediate state change.

User-visible behavior in `APP_VERSION=0.2.34`:

- Crop buttons now show `Saving Crop` with a progress indicator while a crop is being written.
- Crop buttons are disabled while the item is saving, preventing accidental repeated clicks from creating duplicate crops.
- After a crop is saved, the app inserts the crop file into the active session/archive cache immediately.
- The preview/focus/selection switches to the newly created crop.
- The status message explicitly says the crop was saved and that the cropped version is being shown.
- The `Cropped` filter can show the newly created crop without requiring a manual reload.
- Original/crop badges can link immediately because the crop item is now loaded in memory.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `Tests/PhotoDiaryTriageTests/TestSupport.swift`
- `changelog/backlog/PDT-2026-05-27-077-crop-feedback-and-immediate-preview.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build`: passed.
- `./scripts/build_app_bundle.sh`: built `dist/PhotoDiaryTriage.app`.
- bundle metadata checked:
  - `CFBundleShortVersionString`: `0.2.34`
  - `CFBundleVersion`: `111`
  - `PDTLatestFeatureSlug`: `crop-feedback-immediate-preview`

## Blocked Verification

- `swift test --filter Crop`: blocked before test compilation because active Command Line Tools cannot provide XCTest platform paths.
- Current toolchain path: `/Library/Developer/CommandLineTools`.
- Error: `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`.

## Known Gaps

- Manual real-photo verification is still needed for preview handoff and compare-card replacement feel.
- XCTest coverage was added for immediate crop insertion and preview switching, but cannot run on this machine until the Xcode/XCTest toolchain is fixed.
