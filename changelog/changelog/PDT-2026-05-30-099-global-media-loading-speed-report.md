# PDT-2026-05-30-099 global media loading speed — report

item_id: PDT-2026-05-30-099
shipped_release_version: 0.2.54
shipped_feature_slug: global-media-loading-speed
status: implemented_pending_review

## Summary Of What Changed

This follow-up treats the slow Archive View as evidence of a shared media-loading/cache-identity problem, not as an archive-only patch.

- Added lightweight front-matter parsing as shared infrastructure for archive/file manifests.
- Extended per-file manifests to write `thumbnail_cache_key`, preserving the thumbnail identity created during camera/source triage.
- Updated archive scans to read sidecar file manifests and restore:
  - original `media_item_id`
  - `thumbnail_cache_key`
  - captured date
  - camera/lens labels
  - pixel dimensions
  - GPS coordinates
  - archive relative path
- Added a shared `ThumbnailCacheKeyResolver` that reuses known thumbnail keys from current and persisted sessions when archive-scanned items match known imported destinations.
- Wired Archive View cache population through that resolver, so already-known archive files can reuse existing source-side thumbnail cache entries.
- Kept archive scanning byte-safe: the scanner still uses file attributes and tiny text manifests, not full image bytes, for archive metadata.
- Left `0.2.53` progressive scheduling and speed indicator intact for source and archive paths.

## Analysis Notes

The `0.2.53` scheduler made camera triage faster, which showed the remaining archive delay was not simply thumbnail concurrency. Archive scans rebuild `MediaItem`s from archive file paths. Because `CacheKeyBuilder` used file paths, the same copied photo could have one cache key in source triage and another in Archive View. That caused avoidable thumbnail regeneration.

The global fix is to carry media identity through durable metadata:

- new imports persist the source thumbnail cache key in each file manifest;
- archive scans recover that key without reading photo bytes;
- AppState can also reuse known destination-to-thumbnail mappings from current/persisted sessions, which helps existing imported items even before new manifests exist.

## Files Changed

- `Sources/PhotoDiaryTriage/Utilities.swift` — shared front-matter parser.
- `Sources/PhotoDiaryTriage/ArchiveCopySurveyor.swift` — reused the shared parser.
- `Sources/PhotoDiaryTriage/Models.swift` — optional `FileManifest.thumbnailCacheKey`.
- `Sources/PhotoDiaryTriage/ManifestRenderer.swift` — writes `thumbnail_cache_key`.
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift` — includes the thumbnail key in file manifests.
- `Sources/PhotoDiaryTriage/FileScanner.swift` — reads sidecar manifests during archive scans and restores identity/metadata/cache keys without ImageIO.
- `Sources/PhotoDiaryTriage/StateSupport.swift` — shared thumbnail cache-key resolver.
- `Sources/PhotoDiaryTriage/AppState.swift` — applies known thumbnail keys when loading/reusing archive items.
- `Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift` — verifies manifests include thumbnail cache keys.
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift` — verifies archive manifest identity restoration and known-destination cache-key reuse.
- `APP_RELEASE.env` — `0.2.54` / build `131` / `global-media-loading-speed`.

## Verification

- `swift build` — passed.
- `swift test --filter importCoordinatorCommitCopiesSelectedFilesAndWritesManifests` — passed.
- `swift test --filter archiveMediaLoadReusesFileManifestIdentityAndThumbnailKey` — passed.
- `swift test --filter archiveMediaLoadUsesFastFileAttributeScan` — passed.
- `swift test --filter thumbnailCacheKeyResolverReusesKnownImportedDestinationKeys` — passed.
- `swift test` — passed 161 tests.

## Known Gaps Or Follow-up Items

- Existing archive files without persisted sessions or old manifests lacking `thumbnail_cache_key` still need first-time thumbnail generation. Once generated, they benefit from the `0.2.53` progressive scheduler.
- Existing old sidecar manifests are not rewritten in this pass.
- A later global performance pass could add a lightweight aggregate archive index so Archive View does not need to enumerate each walk folder before showing an overview.

## Handoff — Please Test APP_VERSION 0.2.54

Intended user-visible behavior in `APP_VERSION=0.2.54`: camera/source triage remains fast, and Archive View should reuse known/imported thumbnail identities instead of regenerating thumbnails for photos the app already knows. Archive thumbnails should still fill progressively with the existing speed indicator.

Please test `APP_VERSION 0.2.54`.
