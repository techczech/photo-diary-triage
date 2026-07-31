# PDT-2026-07-12-098 Archive Timeline, Contact Sheet, and search

item_id: PDT-2026-07-12-098
shipped_release_version: 0.7.2
shipped_build: 138
shipped_feature_slug: archive-thumbnail-loading
status: archive_thumbnail_loading_shipped_pending_user_test

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
- Archive browsing uses existing Archive Index thumbnails where available and
  generates ordinary cached thumbnails from locally available Archive photos.
  Online-only originals remain placeholders rather than being downloaded
  implicitly.
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
- Online-only Archive originals without index thumbnails remain placeholders
  until the user explicitly runs the bounded backfill. Browsing itself does not
  hydrate those originals.
- The existing Swift 6 sendability warnings in archive migration callbacks and
  one review-grid binding remain; this release introduces no new build warning.

## Installation follow-up

The user reported that the installed app still displayed version 0.6 after the
initial installation. Inspection found that the installed executable,
Info.plist, embedded release record, and Launch Services record all identified
0.7.0 build 136, and the executable matched the tested bundle byte for byte.
However, copying over the existing app had retained the bundle directory's
0.6-era modification date.

The existing bundle was moved intact to `/tmp/Walkfolio-replaced.app`.
`/Applications/Walkfolio.app` was then created as a fresh directory from the
verified bundle, given a current modification date, and explicitly registered
with Launch Services. The fresh installation verifies as 0.7.0 build 136 with
feature slug `timeline-and-search`; its executable checksum matches the tested
bundle and strict deep code-signature verification passes.

## Installed screenshot correction

Dominik's screenshot confirmed that the installed 0.7.0 executable contained
the new Archive sidebar. The visible `06` was the name of an open physical
Unorganised Folder, not the application version. It also exposed a routing
defect: choosing a year or entry type while a folder was open could leave that
folder's photo grid active instead of returning to Timeline or Contact Sheet.

Walkfolio 0.7.1 now treats every year and entry-type choice as navigation back
to the Archive catalogue. It cancels any active folder scan, clears the physical
folder context and photo selection, restores the Archive root, retains the
chosen Timeline or Contact Sheet, and applies the requested filter there. The
photo-grid guidance now uses Trip and Unorganised Folder terminology instead of
the previous photowalk and year/month language.

Verification for the correction:

- The focused regression opens a synthetic `2025/06` Unorganised Folder and
  confirms that both year and entry-type choices return to the Archive root.
- The complete Swift suite passes with 186 tests in two suites and no failures.
- `dist/Walkfolio.app` and `/Applications/Walkfolio.app` both verify as version
  0.7.1, build 137, feature slug `archive-filter-return`.
- The installed executable matches the tested bundle byte for byte, and strict
  deep code-signature verification passes.

## Installed thumbnail-loading correction

Dominik clarified that the screenshot's immediate failure was the grey warning
cards and Retry buttons. The preview path was rejecting every Archive original
without an Archive Index thumbnail, including photos whose bytes were already
available locally.

Walkfolio 0.7.2 replaces that blanket rejection with an availability policy.
Locally available Archive photos may now generate thumbnails in the ordinary
cache. Sparse online-only originals are still rejected before Quick Look is
called, on both the Main Archive and Travel machines, so this correction does
not silently download the cloud collection.

Verification for the correction:

- The focused policy regression confirms that local Archive photos and photos
  outside the Archive are readable for thumbnail generation, while an
  online-only Archive original is not.
- The complete Swift suite passes with 187 tests in two suites and no failures.
- `dist/Walkfolio.app` and `/Applications/Walkfolio.app` both verify as version
  0.7.2, build 138, feature slug `archive-thumbnail-loading`.
- The installed executable matches the tested bundle byte for byte, and strict
  deep code-signature verification passes.
