# PDT-2026-07-03-097 Release B — walk-trip-model

item_id: PDT-2026-07-03-097
shipped_release_version: 0.5.0
shipped_build: 133
shipped_feature_slug: walk-trip-model
status: implemented_review_fixes_bundled_install_blocked

## Summary

Release B implements the Walk/Trip model pivot for Walkfolio. Triage now carries proposed
Walks, source provenance, per-Walk Trip targets, configurable weekday naming, and
configurable Walk/Trip display labels. Copy to archive now opens a closable Walk proposal
sheet before copying, writes one Walk manifest and session log per Walk folder, and writes
Trip manifests for named Trip folders.

## Files changed

- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/WalkTripServices.swift`
- `Sources/PhotoDiaryTriage/ArchivePlanner.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/ManifestRenderer.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Sources/PhotoDiaryTriage/Utilities.swift`
- `Tests/PhotoDiaryTriageTests/WalkTripModelTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `scripts/build_app_bundle.sh`
- `APP_RELEASE.env`

## User-visible behaviour

- Copying from Triage proposes Walk boundaries using selected photos and time/day grouping,
  then shows a closable confirmation sheet where each Walk can be named, split, merged, and
  targeted at the default month Trip, an existing named Trip, or a new named Trip.
- A Triage can add a second Source folder without replacing the current one; imported items
  retain source provenance and grouping is recomputed across the merged set.
- Archive Walk folders expose a context menu action, "Move to Trip...", that moves the Walk
  to an existing named Trip or a newly-created named Trip and rewrites local Markdown/JSONL
  sidecar paths.
- Settings now expose weekday-token style and user-facing Walk/Trip display labels.
- Navigation wording now uses "Current Triage" for the working state. Photo Log library
  semantics remain unchanged.

## Verification performed

- `swift build --disable-sandbox --build-path /tmp/photo-diary-triage-build` with SwiftPM
  and Clang caches pointed at `/tmp`.
- `swift test --disable-sandbox --build-path /tmp/photo-diary-triage-build`: 168 tests
  passed after the review-fix regression tests were added.
- `./scripts/build_app_bundle.sh` via the script path, with `PDT_BUILD_PATH=/tmp/photo-diary-triage-build`
  and `PDT_DISABLE_SWIFTPM_SANDBOX=1`: built `dist/Walkfolio.app`.
- Verified `dist/Walkfolio.app/Contents/Resources/APP_RELEASE.env` reports
  `APP_VERSION=0.5.0`, `APP_BUILD=133`, `APP_FEATURE_SLUG=walk-trip-model`.

## Review-fix pass

Applied the 2026-07-05 Release B review findings before ship:

- Same-day multi-Walk commits now get distinct default Walk titles and share one
  destination reservation set across every Walk plan in the commit. Import now errors if
  a planned destination unexpectedly exists instead of silently skipping the copy.
- The Walk commit editor recomputes proposals every time it opens. Cancelling the editor
  and later changing triage state clears stale proposals so newly-marked photos are not
  omitted from the next commit.
- Per-Walk manifests now scope excluded/candidate/undecided counts to that Walk's items,
  and RAW companion verification events are written into per-Walk session logs.
- Archive layout migration and Walk moves now share one text sidecar rewriter for Markdown,
  JSON, and JSONL sidecars, including Trip folder fields and relative paths.
- Moving an archived Walk between named Trips now updates source and destination Trip
  manifests through shared Trip-manifest maintenance.
- The commit editor offers existing named Trips for each Walk's own year, not only the
  first proposed Walk's year.
- `Move Selected Walk to Trip...` is now available from the Triage menu with
  Command-Shift-T when an archive Walk node is selected.
- Settings can hold empty Walk/Trip display-label fields while the user is editing them;
  defaults are left to read/commit-time fallback.

Additional regression coverage:

- `sameDayTimeClusterWalksGetDistinctDefaultTitlesAndCommitDestinations`
- `cancelWalkCommitEditorThenMarkMoreRecomputesWalkProposals`
- Extended `walkMoverMovesFolderAndRewritesSidecars` for JSON sidecars and source/destination
  Trip manifest membership.

## Known gaps or follow-up items

- Installing to `/Applications` was blocked by this managed session's filesystem permissions.
  `/Applications/Walkfolio.app` remains at `0.4.1` build `132`; the built 0.5.0 bundle is in
  `dist/Walkfolio.app`.
- No manual UI run was performed in this sandbox after bundling.
