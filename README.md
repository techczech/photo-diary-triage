---
title: Walkfolio
updated: 2026-10-02
---

# Walkfolio

**A photo walk diary and archive manager for Mac.** Walkfolio combines fast keyboard-driven triage with a durable photo archive: Sources become Walks, Walks belong to Trips, and readable manifests preserve context beside the photographs.

## Current release

Version **0.7.6, build 142** adds an archive-wide Map and explicit travel-original viewing to the archive recovery and index-only browsing improvements. Copies are verified by SHA-256; interrupted imports reuse recorded destinations; cleanup checks every selected original and RAW companion before deleting a source. Existing Walk notes and membership survive appended imports, and metadata edits update canonical manifests.

Archive moves and layout migration record their plans before changing files. Canonical paths are rewritten without changing human notes or source provenance. Historical folders and hidden material are retained. The derived index publishes complete generations and detects incomplete synchronisation.

On a travel Mac, catalogue, historical folders, photo grids and search read the pinned `_index`. Prepared thumbnails display without original files or folders. RAW companions and crop links are preserved. Routine travel browsing does not preheat originals or generate thumbnails from them; a missing prepared thumbnail stays a placeholder. Travel originals require **Download to view**, including resident files. The action prepares one selected original and opens the preview inside Walkfolio; neighbouring originals remain blocked.

Rebuild the index on the Main Archive machine to add historical folder records. Machines sharing this index should use 0.7.5 or later; older releases do not recognise the new historical-folder record kind.

Map shows located Walks across the filtered archive, with native clustering and direct links to their photo grids. A saved Walk pin takes precedence over the spherical centroid of original photo GPS. Walks and historical folders without a recorded location remain listed. Map data comes entirely from the index and is independent of an open Photo Log.

## Working features

- Review a source SSD in a grid, using mouse and keyboard selection, bursts, time clusters, preview and comparison.
- Mark photos as included, candidate, excluded or undecided; create and reopen resumable Photo Logs.
- Combine Sources into proposed Walks and import selected photographs into default month folders or named Trips.
- Keep readable per-photo and Walk manifests, JSONL logs, notes, locations and coordinates beside the archived files.
- Browse recognised Trips and unorganised historical folders in Timeline or Contact Sheet views, with search over index metadata.
- Prepare persistent 512-pixel thumbnails for one open archive folder, with progress, cancellation, serial downloads, eviction and a 15 GB free-space floor.
- Keep source cleanup behind verification, backup confirmation and the main archive machine role.

## Completion goals

The approved 1.0 scope remains open. Complete contextual location overrides, on-demand LM Studio descriptions, Google Photos delivery, and historical title/date harvesting still require work. The description integration is currently a stub.

The [development goals and acceptance tests](planning/development-plan-walkfolio-reliability.md) explain the intended complete workflow, current evidence and the order of independent development. [CONTEXT.md](CONTEXT.md), [PRD.md](PRD.md) and [DESIGN.md](DESIGN.md) hold the domain and product rules.

## Development

Requires macOS 14 or later and a compatible Swift/Xcode development toolchain.

```sh
swift test --no-parallel
scripts/build_app_bundle.sh
```

The bundle is written to `dist/Walkfolio.app` and signed locally. `PDT_BUILD_PATH` selects a separate build directory; packaging obtains the executable location from Swift rather than assuming a toolchain-specific layout. Native interface tests should run only while the reviewer is watching.

## Records and source

- `Sources/PhotoDiaryTriage/` contains the app.
- `Tests/PhotoDiaryTriageTests/` contains workflow and failure-recovery tests.
- `changelog/backlog/` contains requested work; `changelog/changelog/` contains implementation reports.
- `_index` is disposable. `.walkfolio-recovery` holds operation recovery records and must accompany the archive when recovering an interrupted operation.

MIT licence. See [LICENSE](LICENSE).
