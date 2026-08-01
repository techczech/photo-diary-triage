# PDT-2026-07-31-099 Fast cached thumbnails for Archive folders

item_id: PDT-2026-07-31-099
shipped_release_version: 0.7.3
shipped_build: 139
shipped_feature_slug: archive-thumbnail-cache-speed
status: shipped_pending_user_test

## Summary

Walkfolio 0.7.3 adds an explicit folder-level preparation action to an open
Archive photo grid. It makes a persistent 512-pixel Archive Index thumbnail for
each primary photo in that folder, while preserving the rule that ordinary
browsing never silently downloads online-only originals.

The preparation reuses thumbnails already held in the local application cache,
reads local originals where available, and downloads online-only originals one
at a time. An original downloaded only for preparation is evicted after its
thumbnail is written. The operation stops before free space falls below 15 GB,
shows progress, and can be cancelled without discarding completed thumbnails.

## User-visible behaviour

- An open Archive photo folder now shows **Prepare Thumbnails…** in its header;
  the same action is available in the Archive menu.
- Confirmation states how many photos already have Archive Index thumbnails,
  how many can be copied from the local application cache, how many have local
  originals, and how many require a one-at-a-time download.
- The header replaces the action with progress and a visible Cancel control
  while preparation is running.
- Completed thumbnails are refreshed into the open grid and remain available
  on later visits without reading the full originals.
- Opening a folder now starts only a small initial thumbnail batch. Requests
  from cells that actually enter the viewport are promoted ahead of queued
  background work.
- The existing whole-Archive backfill remains available for deliberate
  maintenance and cannot run concurrently with folder preparation.

## Files changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ArchiveIndex.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ThumbnailScheduler.swift`
- `Tests/PhotoDiaryTriageTests/ArchiveIndexTests.swift`
- `Tests/PhotoDiaryTriageTests/ThumbnailSchedulerTests.swift`
- `docs/adr/0004-folder-scoped-archive-thumbnail-preparation.md`
- `planning/archive-0.7.3-thumbnail-cache-implementation-plan.md`
- Archive backlog and changelog records.

## Verification performed

- The Swift package built successfully.
- The complete serialised test run passed: 190 tests in two suites, with no
  failures.
- New tests confirm that folder-scoped preparation ignores photos outside its
  explicit input, promotes an existing local cached thumbnail without reading
  the original, honours cancellation before new work, and promotes an already
  queued background request when that photo becomes visible.
- `dist/Walkfolio.app` was built and ad-hoc codesigned.
- The built and installed bundles both report version 0.7.3, build 139, and
  feature slug `archive-thumbnail-cache-speed`.
- The installed executable matches the tested bundle byte for byte, and strict
  deep code-signature verification passes.

## Known gaps or follow-up items

- The native interface has not been launched by automation because app testing
  must not take over the user's screen. The installed build is waiting for one
  short check against a real folder with online-only originals.
- Preparing a large online-only folder still incurs a deliberate one-time
  download cost. The speed improvement is persistent reuse on subsequent
  visits, not parallel bulk hydration.
- Existing Swift 6 sendability warnings in archive migration callbacks and one
  review-grid binding remain; this release introduces no new build warning.

## Installation

Walkfolio was quit cleanly before replacement. The previous 0.7.2 bundle was
preserved at `/tmp/Walkfolio-0.7.2-replaced-for-0.7.3.app`. The verified 0.7.3
bundle was installed as a fresh `/Applications/Walkfolio.app`, given a current
modification date, and registered with Launch Services.
