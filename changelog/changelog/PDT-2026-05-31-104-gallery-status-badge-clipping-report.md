# PDT-2026-05-31-104 gallery status badge clipping report

## Summary

Fixed the right-edge clipping of gallery status badges introduced by the density pass.

The grid card now keeps its internal chrome padding inside the fixed grid column width instead of adding padding outside the column. The photo surface fills the bounded card content width, and the status badge has a bounded text width with tail truncation so it stays inside the photo overlay as grid columns change.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-31-104-gallery-status-badge-clipping.md`
- `changelog/backlog.jsonl`

## Verification

- Focused review grid tests:
  - `swift test --filter 'reviewGridMetricsUseRequestedColumnsForCardWidth|reviewGridMetricsKeepCardChromeInsideColumnWidth|reviewGridColumnPreferenceUsesLastMeasuredWidthForReflow|reviewGridClickContextTracksModifiersAndDoubleClick'`
  - Result: 4 tests passed.
- App bundle:
  - `./scripts/build_app_bundle.sh`
  - Result: built `dist/PhotoDiaryTriage.app`.
- Bundle metadata:
  - `CFBundleShortVersionString`: `0.2.58`
  - `CFBundleVersion`: `135`
  - `PDTLatestFeatureSlug`: `gallery-status-badge-clipping`
- Launch check:
  - `open -n dist/PhotoDiaryTriage.app`
  - Result: rebuilt app launched.

## Known Gaps Or Follow-Up Items

- Direct screenshot verification remains blocked by macOS screen-recording privacy UI in this Codex session. Please visually test the running `0.2.58` bundle by changing grid columns and checking that the top-right status badge stays inside each photo.
- The older `/Applications/PhotoDiaryTriage.app` process was already running alongside the rebuilt `dist/PhotoDiaryTriage.app`; test `0.2.58` specifically.

## Release

- Shipped version: `0.2.58`
- Shipped build: `135`
- Shipped feature slug: `gallery-status-badge-clipping`
