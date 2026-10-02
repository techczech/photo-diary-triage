---
title: Walkfolio
updated: 2026-10-02
---

# Walkfolio

**A photo walk diary and archive manager for Mac.** Walkfolio combines fast keyboard-driven triage with a durable photo archive: Sources become Walks, Walks belong to Trips, and readable manifests preserve context beside the photographs.

## Current release

Version **0.7.4, build 140** strengthens import, cleanup, metadata, move and index recovery. Copies are verified by SHA-256; interrupted imports reuse recorded destinations; cleanup checks every selected original and RAW companion before deleting a source. Existing Walk notes and membership survive appended imports, and metadata edits update canonical manifests.

Archive moves and layout migration record their plans before changing files. Canonical paths are rewritten without changing human notes or source provenance. Historical folders and hidden material are retained. The derived index publishes complete generations and detects incomplete synchronisation.

## Working features

- Review a source SSD in a grid, using mouse and keyboard selection, bursts, time clusters, preview and comparison.
- Mark photos as included, candidate, excluded or undecided; create and reopen resumable Photo Logs.
- Combine Sources into proposed Walks and import selected photographs into default month folders or named Trips.
- Keep readable per-photo and Walk manifests, JSONL logs, notes, locations and coordinates beside the archived files.
- Browse recognised Trips and unorganised historical folders in Timeline or Contact Sheet views, with search over index metadata.
- Prepare persistent 512-pixel thumbnails for one open archive folder, with progress, cancellation, serial downloads, eviction and a 15 GB free-space floor.
- Keep source cleanup behind verification, backup confirmation and the main archive machine role.

## Completion goals

The approved 1.0 scope remains open. Fully index-only travel browsing, archive-wide Map and complete location overrides, on-demand LM Studio descriptions, Google Photos delivery, and historical title/date harvesting still require work. The description integration is currently a stub.

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
