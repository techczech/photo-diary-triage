---
item_id: PDT-2026-10-02-101
title: Index-only archive browsing on the travel Mac
shipped_release_version: 0.7.5
shipped_build: 141
shipped_feature_slug: index-only-travel
status: shipped_pending_native_check
---

# Walkfolio 0.7.5: travel browsing from the pinned index

Travel catalogue, grids and search work when only `_index` and prepared thumbnails are present. The main index now records unorganised historical folders without turning them into Trips. Historical file discovery uses metadata rather than image bytes, preserves directory case and groups RAW companions. Canonical photo identities, dimensions and locations survive projection. Crop relationships are recorded in Archive-relative paths and rebased to the open grid, preserving badges, links and family order without opening crop sidecars on the travel machine.

Routine travel browsing does not preheat originals or generate missing thumbnails from resident originals. Prepared previews display; missing ones remain placeholders. Local full-image inspection and explicit download remain separate user actions. Existing sidebar navigation already used the catalogue; unused filesystem tree builders were not involved.

## Verification

- Full suite: **235 tests in two suites passed in 11.341 seconds**.
- Fresh travel root contains only `_index`; a file-manager spy rejects original folder enumeration. Trips, historical folders, grid IDs/dimensions/RAWs and SQLite search work.
- Additional regressions cover traversal/symlink escapes, case-sensitive historical grouping, prepared previews and crop families after originals/sidecars are absent.
- Astra reviewed navigation and compatibility. Findings became fixes and tests for directory case, crop families, shared Photo Log identity, duplicate paths and locked canonical projection.
- The real 0.7.5 build 141 was packaged and locally signed. Installed version/build, executable equality and strict deep signature verification are checked without launching the app.

## Deployment and limits

Rebuild the main archive index to add historical rows. All machines sharing it should update to 0.7.5 or later: older app versions do not recognise the new historical-folder kind. Older field sets remain decodable by the new release. No live archive rebuild, migration, cleanup or headed native check was performed while the reviewer was away.

The approved completion scope continues with archive-wide Map/location workflows, LM Studio descriptions, Google Photos delivery and historical title/date harvesting. Automated fixture tests do not establish OneDrive or native usability behaviour.

Archive preview/link/crop actions resolve the active folder even when a loaded Photo Log shares the same media ID. Successful archive crops refresh the derived index; crops of crops are reconstructed. Duplicate canonical paths fail while retaining the previous index. Targeted projection holds the archive lock from manifest reads through publication. Archive byte guards reject escaping symlinks even for explicit reads.

A final overlapping-cache correction invalidates ancestor views and updates only the active crop folder. The focused live preview/crop/index-refresh regression passed again in 0.094 seconds after this correction. New crop thumbnails remain an explicit Prepare Thumbnails action before travel viewing.
