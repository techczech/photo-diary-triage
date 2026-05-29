# PDT-2026-05-28-085 crop interaction repair report

item_id: PDT-2026-05-28-085
status: implemented
shipped_release_version: 0.2.41
shipped_feature_slug: crop-interaction-repair

## Summary

Fixed the broken crop interaction slice as `APP_VERSION=0.2.41`.
Drag Crop is now a pending, adjustable crop-selection tool rather than an immediate save-on-mouse-up action.
The installed app was rebuilt and relaunched from `/Applications/PhotoDiaryTriage.app`.

## User-Visible Behavior

- Grid thumbnail and metadata double-clicks select the item and open preview again.
- Grid crop/original buttons are no longer covered by the card click target.
- Drag Crop creates a visible pending rectangle with handles.
- Dragging inside the pending rectangle moves it.
- Dragging handles resizes it.
- Mouse-up only leaves the pending crop selected; it does not write a crop file.
- Save Crop explicitly writes the crop and switches to the cropped version.
- Cancel/Escape clears the pending crop without creating duplicate outputs.
- Pending crop rectangles preserve their normalized image area across zoom/layout updates.
- Crop writes use temporary files and clean them up.
- Unknown crop output formats now fall back to bounded JPEG instead of TIFF.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/CropGeometry.swift`
- `Sources/PhotoDiaryTriage/CropService.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-28-085-crop-interaction-repair.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build` passed.
- `swift test` blocked before test compilation because active Command Line Tools cannot provide XCTest platform paths.
- `git diff --check` passed.
- `./scripts/build_app_bundle.sh` passed.
- Installed bundle metadata:
  - `CFBundleShortVersionString=0.2.41`
  - `CFBundleVersion=118`
  - `PDTLatestFeatureSlug=crop-interaction-repair`
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app` passed.
- Running process path: `/Applications/PhotoDiaryTriage.app/Contents/MacOS/PhotoDiaryTriage`.
- System Events saw one `Photo Diary Triage` window and reported `PhotoDiaryTriage` frontmost.
- Computer Use `list_apps` reported `PhotoDiaryTriage` frontmost and running from `/Applications/PhotoDiaryTriage.app`.
- Disk headroom after build/install: about `16 GiB` free on `/System/Volumes/Data`.

## Blocked Verification

- Full automated tests remain blocked by the local XCTest/toolchain issue:
  - `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`.
  - SwiftPM exits with `error: XCTest not available`.
- Computer Use in this session exposed app listing, typing, scrolling, value setting, and secondary actions, but did not expose a UI tree, screenshot, or pointer click action for a real crop gesture.

## Known Gaps

- Manual user review still needs to exercise real crop gestures on photo data:
  - double-click grid thumbnail or metadata row to open preview;
  - enable Drag Crop;
  - drag, move, and resize a pending rectangle;
  - confirm mouse-up does not create a crop file;
  - Save Crop and confirm the app switches to the crop;
  - Cancel/Escape and confirm no duplicate crop appears.
