# PDT-2026-05-27-081 crop links and gallery grouping report

item_id: PDT-2026-05-27-081
status: implemented
shipped_release_version: 0.2.37
shipped_feature_slug: crop-links-gallery-grouping

## Summary

Implemented crop-family ordering and made grid crop links actionable.

User-visible behavior in `APP_VERSION=0.2.37`:

- Original photos sort before their crop versions.
- Crop versions stay adjacent to the original by crop family, even when crop metadata dates differ from the original.
- Grid crop controls now read as actions: `Show Crop`, `Show Latest Crop`, or `Show Original`.
- The grid selection click target now sits behind card content instead of over the crop link button.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ArchivePlanner.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/FileScanner.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-27-081-crop-links-gallery-grouping.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build`: passed.
- `rg` check found no remaining `Self.mediaSort` call sites.
- `git diff --check`: passed.

## Blocked Verification

- `swift test --filter cropFamilySortsOriginalBeforeCropsUsingOriginalDate`: blocked before test compilation because active Command Line Tools cannot provide XCTest platform paths.
- Error remains `XCTest not available`.

## Known Gaps

- Grid link click needs manual app verification after the full crop stack is installed.
- Drag crop affordances, mouse zoom/pan, and broader performance pass remain separate active chunks.
