# PDT-2026-05-23-059: Interactive Image Responsiveness Report

## Summary

Improved the app's perceived responsiveness for archive browsing, preview, compare, and zoom. Archive walk scans now run away from the click path, so selecting an archive walk can update the UI immediately while the folder scan completes in the background.

Preview and compare now use a bounded interactive image decode instead of always decoding full-resolution originals. The shared decode pipeline also preheats selected and nearby images so compare entry, preview navigation, and compare focus changes can reuse in-flight or cached image work.

The scanner now avoids reading metadata for RAW companion candidates before the primary file is known. This reduces archive and source scan work for JPEG+RAW sets while preserving companion grouping.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/DecodedImagePipeline.swift`
- `Sources/PhotoDiaryTriage/FileScanner.swift`
- `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift`
- `changelog/backlog/PDT-2026-05-23-059-interactive-image-responsiveness.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- Ran `swift test`: 108 tests passed.
- Built the packaged app with `./scripts/build_app_bundle.sh`.
- Launched `dist/PhotoDiaryTriage.app` successfully and confirmed the `PhotoDiaryTriage` process was running.

## Known Gaps

- No manual timing trace was captured in this pass.
- Archive scans still need to read primary-file metadata before the full item list is available. This pass makes that work non-blocking and smaller, but it does not introduce a streaming archive list.

## Shipped Release

- APP_VERSION: 0.2.20
- APP_BUILD: 97
- APP_FEATURE_SLUG: interactive-image-responsiveness
