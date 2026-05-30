# PDT-2026-05-30-100 measured global media speed report

## Summary

Implemented a measured global media speed fix for Archive View and shared thumbnail/preview paths.

The previous `0.2.54` pass generated thumbnail cache files quickly but did not update archive thumbnail slots progressively. This pass fixes the shared completion path so archive-scanned items are decoded into the same thumbnail registry as session items.

The app now also detects online-only / dataless OneDrive files and shows that state instead of silently trying to thumbnail or preview files that are not fully local.

## Measurement Proof

Same benchmark, same fixture, same machine:

- Baseline before fix:
  - `archive_scan_ms`: `4`
  - `first_cache_file_ms`: `26`
  - `all_cache_files_ms`: `26`
  - `first_visible_slot_ms`: `null`
  - `all_visible_slots_ms`: `null`
  - `slot_timeout_ms`: `2000`
- Final after fix:
  - `archive_scan_ms`: `10`
  - `first_cache_file_ms`: `24`
  - `all_cache_files_ms`: `24`
  - `first_visible_slot_ms`: `111`
  - `all_visible_slots_ms`: `111`
  - `slot_timeout_ms`: `2000`

Interpretation: thumbnail cache generation was never the only bottleneck. Archive View failed to publish generated thumbnails into visible slots. The new path changes visible archive thumbnail availability from "not observed within 2 seconds" to all visible slots populated in about `111 ms` on the benchmark.

## OneDrive Evidence

Microsoft documents that OneDrive Files On-Demand exposes online-only files that do not occupy local space until opened, and that macOS 12.1+ makes Files On-Demand part of the macOS File Provider behaviour. Microsoft also documents scriptable Files On-Demand states.

Local archive evidence on this Mac:

- Archive root: `/Users/dominiklukes/Library/CloudStorage/OneDrive-Personal/Pictures`
- Sample walk: `/Users/dominiklukes/Library/CloudStorage/OneDrive-Personal/Pictures/2026/05 - May/12-Tuesday-2026-05-12-tuesday`
- Media files in sampled walk: `9`
- Dataless media files in sampled walk: `9`
- Sample URL resource values:
  - `allocated=0`
  - `totalAllocated=0`
  - `ubiquitous=true`
  - `status=NSURLUbiquitousItemDownloadingStatusNotDownloaded`
- Sample `stat` flags:
  - `compressed,dataless`
  - `blocks=0`

QuickLook thumbnail generation on one dataless sample failed quickly without hydration:

- `quicklook=failure`
- `elapsed_ms=239`
- `blocks` stayed `0`
- flags stayed `compressed,dataless`

So the safe app behaviour is: do not force ImageIO/full-image decode on online-only archive files; show the cloud-only state clearly and let the user intentionally download/pin the file outside this silent browsing path.

Sources:

- Microsoft Support, OneDrive Files On-Demand for Mac: https://support.microsoft.com/en-us/office/save-disk-space-with-onedrive-files-on-demand-for-mac-529f6d53-e572-4922-a585-e7a318c135f0
- Microsoft Support, macOS 12.1+ Files On-Demand behaviour: https://support.microsoft.com/en-au/office/fix-onedrive-files-on-demand-issues-on-macos-12-1-or-later-8c99b82e-bf6e-4bb1-a3df-d0cc5bcbff93
- Microsoft Learn, query/set Files On-Demand states on Mac: https://learn.microsoft.com/en-us/sharepoint/files-on-demand-mac

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/DecodedImagePipeline.swift`
- `Sources/PhotoDiaryTriage/FileLocality.swift`
- `Sources/PhotoDiaryTriage/FileScanner.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/PreviewStore.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/MediaLoadingBenchmarkTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-30-100-measured-global-media-speed.md`

## Verification

- Baseline benchmark before optimization:
  - `PDT_RUN_MEDIA_BENCHMARK=1 PDT_MEDIA_BENCHMARK_ITEM_COUNT=24 swift test --filter mediaLoadingBenchmarkReportsArchiveTimings`
- Final benchmark after optimization:
  - `PDT_RUN_MEDIA_BENCHMARK=1 PDT_MEDIA_BENCHMARK_ITEM_COUNT=24 swift test --filter mediaLoadingBenchmarkReportsArchiveTimings`
- Focused tests:
  - `swift test --filter 'archiveThumbnailGenerationUpdatesArchiveSlot|onlineOnlyThumbnailRequestShowsCloudStateWithoutRetryFailure|fileLocalityDetectorTreatsDatalessUbiquitousFilesAsOnlineOnly'`
- Full tests:
  - `swift test`
  - `165` tests passed.

## Known Gaps Or Follow-Up Items

- Online-only files cannot be thumbnailed from local bytes without hydration. The app now makes this visible and avoids silent mass download attempts, but intentional download/pin controls remain a future workflow slice.
- Microsoft `OneDrive /getpin` returned errors for sampled paths on this machine, so the implementation relies on macOS resource values and dataless allocation evidence rather than the OneDrive CLI output.

## Release

- Shipped version: `0.2.55`
- Shipped build: `132`
- Shipped feature slug: `measured-global-media-speed`
