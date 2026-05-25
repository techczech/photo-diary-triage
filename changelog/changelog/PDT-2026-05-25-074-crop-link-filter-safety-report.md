# PDT-2026-05-25-074 crop link filter and original safety report

item_id: PDT-2026-05-25-074
status: implemented
shipped_release_version: 0.2.32
shipped_feature_slug: crop-link-filter-safety

## Summary

Added crop/original awareness across browsing, filtering, preview links, and cleanup safety.

User-visible behavior in `APP_VERSION=0.2.32`:

- `Cropped` is available in the review filter menu.
- The `Cropped` filter shows both original images that have crop outputs and crop files linked to an original.
- Original cards show a `Has Crop` badge.
- Crop cards show a `Crop` badge.
- Clicking a crop badge opens the linked original or latest crop when that linked item is loaded.
- Archive/source browsing sorts crop files before their originals within the same timestamp/name family.
- Cleanup keeps an original source file when that original has crop output recorded by the crop manifest.
- Cleanup status stays `source_cleanup_pending` when crop-linked originals are deliberately preserved.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserModels.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/FileScanner.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/InlineSectionOrganizer.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-25-074-crop-link-filter-safety.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift test --filter Crop`: passed, 5 Swift Testing tests.
- `swift test`: passed, 133 Swift Testing tests.
- `./scripts/build_app_bundle.sh`: built `dist/PhotoDiaryTriage.app`.
- bundle metadata checked:
  - `CFBundleShortVersionString`: `0.2.32`
  - `CFBundleVersion`: `109`
  - `PDTLatestFeatureSlug`: `crop-link-filter-safety`
- launched `dist/PhotoDiaryTriage.app` for smoke check.

## Known Gaps

- Linked crop/original preview requires both files to be loaded in the current browser/session cache.
- Existing crop files created before this release appear as linked after the folder is rescanned.
- Cleanup safety is conservative: crop-linked originals remain pending rather than being silently removed.

## Follow-Up Candidates

- Add an inspector crop history section.
- Add a direct "reveal linked original/crop in Finder" action.
- Auto-refresh the active folder after a crop is written.
- Add a dedicated crop-pair compare view.
