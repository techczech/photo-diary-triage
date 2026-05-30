# PDT-2026-03-24-015 Import Checksum Verification Report

## Summary

- Added an import verification setting with `Size Only` and `SHA-256 Checksum` modes.
- Kept `Size Only` as the default for existing speed and compatibility.
- Added SHA-256 verification for primary copied photos and RAW companion files.
- Run checksum work in a detached utility task so large-file hashing does not run directly on the UI actor.
- Added verification event details for `verification_mode`, `size_bytes`, and checksum hash when checksum mode is active.
- Added Settings UI under `Backup > Import Verification`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/StateSupport.swift`
- `Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift`
- `changelog/backlog/PDT-2026-03-24-015-import-checksum-verification.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test --filter ImportWorkflowTests`
  - 11 tests passed.
- `swift test`
  - 135 tests passed.
- `./scripts/build_app_bundle.sh`
  - Built `dist/PhotoDiaryTriage.app`.
- Bundle metadata verified:
  - `CFBundleShortVersionString`: `0.2.33`
  - `CFBundleVersion`: `110`
  - `PDTLatestFeatureSlug`: `import-checksum-verification`
- Launched `dist/PhotoDiaryTriage.app`.
  - Confirmed running process from rebuilt bundle.

## Known Gaps Or Follow-Up Items

- Checksum mode strengthens copied-file verification but does not prove an independent cloud or off-device backup has completed.
- Checksum hashes are recorded in session log verification events, not yet in per-file Markdown manifests.
- There is no per-file checksum progress bar during the post-copy verification phase.

## Shipped Release

- APP_VERSION: `0.2.33`
- APP_BUILD: `110`
- APP_FEATURE_SLUG: `import-checksum-verification`
