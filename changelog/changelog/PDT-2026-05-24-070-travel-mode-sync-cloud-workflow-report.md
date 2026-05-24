# PDT-2026-05-24-070: Travel mode sync and cloud workflow report

## Summary

- Added a machine role setting for `Main Archive` vs `Travel`.
- Added a configurable OneDrive `Pictures` root used as the canonical cross-machine archive identity.
- Added OneDrive/Pictures-relative archive paths to copied media items, companion files, file manifests, and walk manifests.
- Added per-log JSON sync export under `.photo-diary-triage/photo-logs/` inside the configured OneDrive `Pictures` folder.
- Added a settings action to import synced photo-log state and remap copied-photo destinations to the current machine's OneDrive root.
- Blocked source cleanup for travel-role sessions so SD card source files remain retained backup.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ArchiveCopySurveyor.swift`
- `Sources/PhotoDiaryTriage/ArchiveRelativePathResolver.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/ManifestRenderer.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/PhotoLogSyncStore.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/StateSupport.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/TestSupport.swift`
- `Tests/PhotoDiaryTriageTests/TravelModeSyncTests.swift`
- `changelog/backlog/PDT-2026-05-24-070-travel-mode-sync-cloud-workflow.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
- `swift test`
  - 128 tests passed.
  - Added coverage for OneDrive-relative path remapping, copied manifest relative paths, travel cleanup blocking, and sync-store import remapping.

## Known Gaps Or Follow-Up Items

- OneDrive cloud upload completion is not yet detected. The app records local copy verification and portable state; OneDrive upload status remains outside this slice.
- Google Photos reduced-JPEG CLI handoff is still deferred.
- Sync conflict UI is minimal. Newer local sessions win over older synced records; richer conflict review can come later.

## Shipped Release

- APP_VERSION: `0.2.29`
- APP_BUILD: `106`
- APP_FEATURE_SLUG: `travel-mode-sync-cloud-workflow`
