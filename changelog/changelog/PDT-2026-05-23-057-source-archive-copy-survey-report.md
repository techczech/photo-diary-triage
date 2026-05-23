# PDT-2026-05-23-057: Source Archive Copy Survey Report

## Summary

The SD-card/source view now runs a read-only archive copy survey for every visible source item. The survey checks per-photo Markdown manifests under the configured archive root and marks source files that already have a matching archive copy on disk.

The review grid and list now show an `On Disk` metadata badge for source items that are not in a photo log but already appear in the archive. Photo-log ownership badges still take precedence when a file is already in a log.

## Files Changed

- `Sources/PhotoDiaryTriage/ArchiveCopySurveyor.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-23-057-source-archive-copy-survey.md`

## Verification

- Ran `swift test --filter ReviewInteractionTests`; 54 tests passed.
- Ran `swift test`; 104 tests passed.
- Built `dist/PhotoDiaryTriage.app`.
- Launched `dist/PhotoDiaryTriage.app`.
- Verified bundle metadata reports version `0.2.18` and build `95`.

## Known Gaps

- The survey uses existing per-photo Markdown manifests. Archive files without matching manifests are not inferred by filename alone.
- Dated source items search matching archive year/month folders for speed. Undated source items still fall back to the archive root.
- Manual verification was limited to launching the packaged app; the `On Disk` badge still needs visual confirmation against the live SD card.

## Shipped Release

- APP_VERSION: 0.2.18
- APP_BUILD: 95
- APP_FEATURE_SLUG: source-archive-copy-survey
