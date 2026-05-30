# PDT-2026-05-30-097 Reconcile checksum verification with map/crop main - report

## Item ID

PDT-2026-05-30-097

## Summary

- Reconciled the local checksum-verification work onto latest `origin/main`.
- Kept latest map, crop, responsiveness, and location-assignment work from `0.2.51`.
- Added `0.2.52` release metadata for the reconciled build.
- Preserved the local archive-intelligence review note as planning history.
- Fixed two crop-test regressions found during verification:
  - crop relationship paths now stay relative for root-level files.
  - test grid pixel generation no longer overflows `UInt8`.
- Corrected the crop nudge test to use a valid starting rectangle while preserving existing crop clipping semantics.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/StateSupport.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-26-075-original-intent-archive-intelligence-review.md`
- `changelog/backlog/PDT-2026-05-30-097-reconcile-checksum-with-map-crop-main.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test --filter ImportWorkflowTests`
  - 11 tests passed.
- `swift test --filter cropNudgeClampsWithinImage`
  - passed after correcting the test fixture.
- `swift test --filter CropServiceTests --no-parallel`
  - 12 tests passed.
- `swift test`
  - 157 tests passed.
- JSONL validation:
  - `changelog/backlog.jsonl`: valid line-delimited JSON.
  - `changelog/changelog.jsonl`: valid line-delimited JSON.

## Known Gaps Or Follow-Up Items

- Checksum hashes are still recorded in session-log verification events, not in per-file Markdown manifests.
- Checksum mode proves copied-file identity, not independent cloud/off-device backup completion.
- The older `PDT-2026-03-24-015` checksum report remains as historical local context; this report is the shipped reconciliation record.

## Shipped Release

- APP_VERSION: `0.2.52`
- APP_BUILD: `129`
- APP_FEATURE_SLUG: `reconcile-checksum-map-crop`
