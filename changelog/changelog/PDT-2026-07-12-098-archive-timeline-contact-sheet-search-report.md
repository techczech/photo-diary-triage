# PDT-2026-07-12-098 Archive Timeline, Contact Sheet, and search

item_id: PDT-2026-07-12-098
shipped_release_version: 0.7.0
shipped_build: 136
shipped_feature_slug: timeline-and-search
status: shipped_pending_user_test

## Summary

Walkfolio 0.7.0 replaces the Archive's inferred year/month/folder tree with two
views over one mixed catalogue: Timeline and Contact Sheet. Manifest-backed Trips
and physical folders that have not yet been organised appear together. Years and
entry types filter the current view rather than opening a different browsing
structure.

The implementation follows the locked mockup and
`docs/adr/0003-archive-browse-includes-unorganised-folders.md`. It does not use
folder depth or the approximate 2016 change in the physical library as evidence
that a folder is a month, Trip, or Walk.

## User-visible behaviour

- Archive opens in Timeline by default and offers Contact Sheet as a persistent
  alternate view. The chosen view and visible selection survive filtering.
- Year and type choices filter the same Archive view. Search covers indexed
  filenames, descriptions, titles, notes, locations, and camera information.
- Recognised Trips open to their indexed Walks and then to the existing photo
  grid.
- An Unorganised Folder opens directly to its existing photos without moving,
  renaming, or rewriting its contents.
- `Organise as a Trip…` is a separate visible and contextual action that opens
  the folder in Triage; no organisation occurs merely by browsing.
- Archive browsing uses existing Archive Index thumbnails where available.
  Missing previews remain placeholders rather than implicitly downloading
  archived originals.
- Archive thumbnail backfill now stops below a 15 GB free-space floor, processes
  one original at a time, supports cancellation, and requests eviction only for
  an original that the operation newly hydrated.
- Timeline, Contact Sheet, search focus, opening, organisation, preview display,
  and catalogue refresh are available through menus and keyboard commands.

## Files changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ArchiveBrowserViews.swift`
- `Sources/PhotoDiaryTriage/ArchiveCatalogue.swift`
- `Sources/PhotoDiaryTriage/ArchiveIndex.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/PreviewStore.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ArchiveCatalogueTests.swift`
- `Tests/PhotoDiaryTriageTests/ArchiveIndexTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `planning/archive-0.7.0-implementation-plan.md`
- Archive backlog and changelog records.

## Verification performed

- The package built successfully with repository-local SwiftPM and Clang caches.
- The complete serialised Swift test run passed: 185 tests in two suites, with
  no failures.
- New tests cover mixed Trips and irregular folders, rejection of stale
  depth-inferred Trips, year/type filtering, selection continuity, search
  fields, search-to-parent mapping, preferences, bounded low-space thumbnail
  behaviour, and eviction policy.
- `dist/Walkfolio.app` was built and ad-hoc codesigned.
- Bundle and installed-app metadata were verified as:
  - `CFBundleShortVersionString=0.7.0`
  - `CFBundleVersion=136`
  - `PDTLatestFeatureSlug=timeline-and-search`
- The installed app passed strict deep code-signature verification.
- Tracking JSONL files were validated line by line with `json.loads`.

## Known gaps or follow-up items

- The native interface has not been launched by automation because app testing
  must not take over the user's screen. The installed build is waiting for a
  short user check against the real Archive.
- Existing Archive folders without index thumbnails show placeholders until the
  user explicitly runs the bounded backfill. Browsing itself does not hydrate
  those originals.
- The existing Swift 6 sendability warnings in archive migration callbacks and
  one review-grid binding remain; this release introduces no new build warning.
