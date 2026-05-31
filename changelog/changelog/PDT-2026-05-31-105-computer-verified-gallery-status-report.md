# PDT-2026-05-31-105 computer verified gallery status report

## Summary

Reworked the Camera Triage grid status overlay after Computer Use confirmed that `0.2.58` still clipped the long `Undecided` badge.

Mutable Camera Triage cards no longer render a long right-edge decision status pill. The visible decision state now comes from the S/C/X/R chip row over the photo, so the edge of each image stays clean as the grid column count changes. Copied/read-only exceptional states can still show compact badges.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-31-105-computer-verified-gallery-status.md`
- `changelog/backlog.jsonl`

## Verification

- Pre-fix Computer Use verification:
  - Launched rebuilt `0.2.58` from `dist/PhotoDiaryTriage.app`.
  - Switched to Camera Triage.
  - Confirmed the visible gallery still showed clipped right-edge `Undecided` status pills.
- Focused review grid tests:
  - `swift test --filter 'reviewGridMetricsUseRequestedColumnsForCardWidth|reviewGridMetricsKeepCardChromeInsideColumnWidth|reviewGridColumnPreferenceUsesLastMeasuredWidthForReflow|reviewGridClickContextTracksModifiersAndDoubleClick'`
  - Result: 4 tests passed.
- App bundle:
  - `./scripts/build_app_bundle.sh`
  - Result: built `dist/PhotoDiaryTriage.app`.
- Bundle metadata:
  - `CFBundleShortVersionString`: `0.2.59`
  - `CFBundleVersion`: `136`
  - `PDTLatestFeatureSlug`: `computer-verified-gallery-status`
- Post-fix Computer Use verification:
  - Launched rebuilt `0.2.59` from `dist/PhotoDiaryTriage.app`.
  - Switched to Camera Triage.
  - Verified visible grid cards no longer show the clipped right-edge `Undecided` pill.
  - Clicked the grid `+` and `-` column controls to verify both 5-column and 4-column layouts remain free of the clipped status text.

## Known Gaps Or Follow-Up Items

- A hover tooltip can still appear over a photo when the pointer rests on a card during Computer Use. That is separate from the status badge clipping issue.
- The gallery keeps the single metadata line under each photo.

## Release

- Shipped version: `0.2.59`
- Shipped build: `136`
- Shipped feature slug: `computer-verified-gallery-status`
