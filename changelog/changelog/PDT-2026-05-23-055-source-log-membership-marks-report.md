# PDT-2026-05-23-055: Source Log Membership Marks Report

## Summary

Source inbox browsing now keeps the full SD-card contents visible even when some files already belong to a photo log. Those already-owned files now show a compact ownership badge directly on the review card and list row:

- `In Log: <title>` for files already assigned to a photo log.
- `Copied to <title>` for files already copied into the archive.

This keeps the source view faithful to the card while still making duplicate-log ownership visible at a glance.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-23-055-source-log-membership-marks.md`

## Verification

- Ran `swift test --filter ReviewInteractionTests`; 52 tests passed.
- Ran `swift test`; 102 tests passed.
- Built `dist/PhotoDiaryTriage.app`.
- Launched `dist/PhotoDiaryTriage.app`.
- Verified bundle metadata reports version `0.2.16` and build `93`.

## Known Gaps

- This release marks already-owned source files, but it does not yet add archive-library ownership markers outside the source inbox workflow.
- Manual UI verification was limited to launching the packaged app; the ownership badge layout was not screenshot-checked in an automated UI pass.

## Shipped Release

- APP_VERSION: 0.2.16
- APP_BUILD: 93
- APP_FEATURE_SLUG: source-log-membership-marks
