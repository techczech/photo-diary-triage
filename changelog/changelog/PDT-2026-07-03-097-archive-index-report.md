# PDT-2026-07-03-097 Release C — archive-index

item_id: PDT-2026-07-03-097
shipped_release_version: 0.6.0
shipped_build: 135
shipped_feature_slug: archive-index
status: release_c_review_fixes_bundled_pending_user_test

## Summary

Release C implements WP2 / ADR 0002: durable Archive Index JSONL shards, archive-side
thumbnails, explicit index maintenance commands, and a travel-mode byte-read guard. The
index is derived and rebuildable; Trip, Walk, and file manifests remain the source of truth.

Post-review hardening fixed the confirmed Release C defects before shipment:

- Archive Index writes are now gated by machine role and run only on `.mainArchive`; travel
  machines keep manifest edits writable but `_index` read-only, with File-menu commands
  disabled and explained.
- All index mutations route through `ArchiveIndexMutationQueue`, which serializes updates and
  coalesces concurrent rebuild requests.
- Import commits no longer await or propagate thumbnail/index failures; Archive Index refresh
  runs after the visible copy/manifests complete and reports failures through status/logging.
- Metadata edits and Walk moves now replace targeted Walk/Trip index rows instead of doing a
  full rebuild, and Walk moves remove old-path rows.
- Successful archive layout migration now schedules a serialized index rebuild.
- Thumbnail names include archive-relative path identity plus extension, so RAW/JPEG and
  same-stem files do not alias.
- Travel-mode byte-read checks cache online-only verdicts by URL, warm archive-folder verdicts
  off the main render path, resolve the archive root once per policy, and avoid misclassifying
  tiny local files.
- The blocked travel placeholder now also has a visible Triage-menu keyboard path:
  `Download Selected Archive Photo to View`.

## Files changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ArchiveIndex.swift`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/CropService.swift`
- `Sources/PhotoDiaryTriage/DecodedImagePipeline.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/PreviewStore.swift`
- `Sources/PhotoDiaryTriage/Utilities.swift`
- `Tests/PhotoDiaryTriageTests/ArchiveIndexTests.swift`
- `Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/changelog/PDT-2026-07-03-097-archive-index-report.md`

## User-visible behaviour

- Each import now writes Archive Index data under `<archiveRoot>/_index/`:
  - year-sharded JSONL at `_index/index-<year>.jsonl`
  - per-photo thumbnails at `_index/thumbs/<year>/<file-stem>.jpg`
- The File menu now includes:
  - `Backfill Archive Index Thumbnails...`
  - `Rebuild Archive Index...`
- In travel mode, those Archive Index write commands are disabled with help text explaining
  that `_index` is maintained only on the Main Archive machine.
- Backfill walks the archive, generates missing thumbnails, throttles between thumbnail
  writes, and updates the status message with progress.
- Rebuild regenerates JSONL shards from manifests/folders. If the index disagrees with
  manifests, rebuilding makes the manifests win.
- Travel mode blocks implicit byte reads for online-only archive photos in:
  - app thumbnail generation
  - full-image decode
  - crop creation
- When a travel-mode preview/compare view reaches an online-only archive photo, it shows the
  `_index` thumbnail when present and offers `Download to view` as the explicit hydration
  action.
- The Triage menu also exposes `Download Selected Archive Photo to View`
  (`Command-Shift-D`) for keyboard/UI parity.

## Verification performed

- `swift build --disable-sandbox --build-path /tmp/photo-diary-triage-build` with SwiftPM
  and Clang caches pointed at `/tmp`.
- `swift test --disable-sandbox --build-path /tmp/photo-diary-triage-build`: 175 tests
  passed.
- `./scripts/build_app_bundle.sh` with `PDT_BUILD_PATH=/tmp/photo-diary-triage-build` and
  `PDT_DISABLE_SWIFTPM_SANDBOX=1`: built `dist/Walkfolio.app`.
- Verified bundle metadata:
  - `APP_VERSION=0.6.0`
  - `APP_BUILD=135`
  - `APP_FEATURE_SLUG=archive-index`
- JSONL tracking files validated line-by-line with `json.loads`.

## Test coverage added

- `archiveIndexRebuildsEntriesFromWalkFolderManifests`
- `archiveByteReadPolicyTreatsSparseArchiveFileAsOnlineOnlyInTravelMode`
- `archiveByteReadPolicyDoesNotTreatTinyLocalFilesAsOnlineOnly`
- `archiveIndexThumbnailNamingUsesArchiveRelativePathAndExtension`
- `archiveIndexMutationQueueSerializesConcurrentWalkUpdates`
- `archiveIndexMutationQueueDoesNotWriteInTravelMode`
- `importCoordinatorCommitSurvivesUnwritableArchiveIndexPath`

## Known gaps or follow-up items

- This managed sandbox did not validate the allocated-size heuristic against a real OneDrive
  online-only file. The sparse-file unit test covers the same filesystem signal. The manual
  Release C test should validate one real online-only archive item on the travel machine.
- Per-file AI descriptions remain placeholders until Release F.
- Installation to `/Applications` was intentionally not attempted; the user asked to verify,
  commit, and install outside the sandbox.
