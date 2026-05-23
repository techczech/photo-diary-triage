# PDT-2026-05-23-056: Owned Item Log Status Badges Report

## Summary

Owned source items now show the status from their owning photo log instead of showing the freshly scanned source item as `Undecided`.

When browsing the SD card, an item already in a log still shows the `In Log` or `Copied to` ownership badge, and its status pill now uses the log's real `Included`, `Candidate`, or `Excluded` state. When opening a photo log directly, copied/imported items now keep a visible `Copied` badge.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-23-056-owned-item-log-status-badges.md`

## Verification

- Ran `swift test --filter ReviewInteractionTests`; 53 tests passed.
- Ran `swift test`; 103 tests passed.
- Built `dist/PhotoDiaryTriage.app`.
- Launched `dist/PhotoDiaryTriage.app`.
- Verified bundle metadata reports version `0.2.17` and build `94`.

## Known Gaps

- Manual verification was limited to launching the packaged app. The source/log badge layout still needs visual confirmation with real photo-log data.

## Shipped Release

- APP_VERSION: 0.2.17
- APP_BUILD: 94
- APP_FEATURE_SLUG: owned-item-log-status-badges
