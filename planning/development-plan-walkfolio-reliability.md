---
title: Walkfolio development goals and acceptance tests
status: active
updated: 2026-10-02
owner: Walkfolio
release: 0.7.9
source_records:
  - planning/dictated-idea-scope.md
  - CONTEXT.md
  - PRD.md
  - DESIGN.md
  - changelog/backlog/PDT-2026-07-03-097-photo-diary-completion-plan.md
  - docs/adr/0001-archive-layout-trips-as-month-level-folders.md
  - docs/adr/0002-archive-index-derived-jsonl-in-pinned-folder.md
  - docs/adr/0003-archive-browse-includes-unorganised-folders.md
  - docs/adr/0004-folder-scoped-archive-thumbnail-preparation.md
---

# Walkfolio: the outcome and how to prove it

**Walkfolio should manage a photographic life: new camera and phone photos, an older archive, and the stories attached to both.** Fast triage is essential, but the intended destination is an archive manager that remains useful on a travel Mac and keeps its records in readable files.

This plan reconciles the original dictated scope, the settled Walk/Trip model, the approved completion plan and subsequent Archive browsing decisions. The complete 1.0 scope remains committed. A passing safety release does not establish that every 1.0 feature exists.

## What the history establishes

- The original problem was selecting and explaining photos without deleting during review or losing notes. Grid review, bursts, time clusters, comparison and keyboard controls support that decision.
- The later domain decision separates **Sources**, an outing called a **Walk**, and a physical grouping of Walks called a **Trip**. A Walk can combine camera and phone material; several Walks can occur on the same day.
- The archive remains a normal folder tree. Manifests carry canonical records; SQLite and the pinned `_index` are replaceable projections. An old folder does not become a Trip just because its path resembles one.
- The approved completion scope includes archive-wide browsing, locations, on-demand LM Studio descriptions, Google Photos album delivery and ordinary triage for historical folders. These are not optional substitutes for the safety work.
- Subsequent browsing decisions preserve recognised Trips alongside unorganised historical folders, with Timeline and Contact Sheet views. Thumbnail preparation is an explicit action on one open folder, with progress, cancellation, serial hydration and a 15 GB free-space floor.
- Photo editing beyond the existing crop workflow, GPX correlation, semantic search and ratings remain outside the agreed completion scope.

## Development goals

| Goal | Acceptance test | State after 0.7.9 |
|---|---|---|
| Keep original photos safe. | Corrupt an equal-size copy, remove a destination, alter source and destination together, or lose a RAW copy. Import/cleanup must reject the operation and retain the source. Backup and machine-role gates apply inside the service. | Automated regressions pass. |
| Recover interrupted imports without duplicate copies. | Fail the second copy or a manifest write, restart from the original Photo Log and finish the recorded destinations. Changed selections, source paths or backup consent must not be restored silently. | Automated regressions pass; immutable plans and compact per-file checkpoints implemented. |
| Preserve stories when editing and appending. | Edit notes in a two-Walk import, change long titles/locations, append a PNG after a JPG, then remove the index and rebuild on a relocated archive. Recover both photo identities, independent Walk details, coordinates and earlier text. | Automated regressions pass. |
| Move and migrate without losing context. | Test occupied destination names, same-Trip moves, interrupted renaming, return moves and reused source paths. Reject invalid manifests and escaping symlinks before mutation. Retain hidden/pre-app material and Trip titles; canonical reconstruction and saved Photo Log paths must agree. | Automated regressions pass. Original media renames use filesystem metadata, without opening photo bytes. |
| Publish a complete derived index. | Fail a new generation write, corrupt its pointer or remove one synchronised year shard. The previous index remains intact, full rebuild repairs the pointer, and incomplete synchronisation is reported. Delayed thumbnail work must not overwrite later metadata. | Automated regressions pass. Generations include expected shard hashes. |
| Browse the whole archive on a travel Mac. | Copy only `_index` and thumbnails to a fresh archive root; browse Trips and historical folders, open their grids and search without manifests, originals or folder enumeration. Missing thumbnails produce a placeholder. | Automated fresh-root workflow passes with only the pinned index. Historical folders, RAW groups, crop families, search and prepared previews work without original-folder enumeration. Routine travel browsing denies original preheat/thumbnail generation. Full viewing requires explicit per-path consent, including resident originals; revoked decodes and timed-out downloads cannot grant access. |
| Use meaningful archive locations. | Walk coordinates survive reconstruction; pin/GPS precedence and photo/cluster overrides survive relaunch. An archive-wide Map opens the correct Walk entirely from index records. | Archive-wide clustered Walk Map, pin/GPS precedence, pair validation, centroid edge cases and index-only navigation pass regressions. Contextual canonical Walk/photo/shared-group editing, raw-GPS preservation, clear fallback, recoverable multi-file saves, move guards and travel projection pass regressions. Trip label overrides, stable default/named identities, clear/fallback, append/move member preservation, mixed-layout migration recovery and index-only reconstruction pass in 0.7.9. |
| Describe archived material on demand. | Inject an LM Studio service, describe one photo and a Walk/Trip, round-trip model/date provenance independently of human notes, then retry/cancel a historical batch without starting work during triage. | Description provider is not yet implemented. Client, queue, canonical provenance and UI remain. |
| Deliver original-quality Google Photos albums reliably. | Against a test account, create one Trip album, verify media membership, interrupt/retry and avoid duplicate delivery. Store membership durably; represent previously synced material explicitly. | OAuth/upload/membership implementation remains. Live account authorisation and external delivery require a separate concrete validation step. |
| Process historical folders through normal triage. | Open a copied old folder, retain its keep-all starting stance, derive title/date hints, import verified copies into an existing/new Trip and recover manifests/index. Sources remain untouched during review. | Historical source actions, keep-all defaults, reload reconciliation, title/date hints, uncertain date provenance, reviewed Trip targets, byte-verified recognition, locked confirmed Copy retry through AppState and recorded archive-source cleanup pass. Native picker/date-review confirmation remains. |
| Preserve speed and usability. | Full selection/keyboard/compare tests continue passing. Measure large-session import recovery; queue visible thumbnails ahead of background work. Check the packaged app in the native interface without disturbing real source material. | Automated suite and bounded recovery benchmark pass. Native/OneDrive checks remain distinct. |

## Order of independent work

1. Finish and verify the 0.7.4 safety foundation; package the actual signed app and keep the release reproducible.
2. Index-only travel catalogue/grid/search and routine preview tests pass in 0.7.5. Rebuild the main index to include historical rows; shared machines need this release or later.
3. Archive-wide Map is implemented in 0.7.6. Contextual canonical photo/shared-group location overrides are implemented in 0.7.7. Historical metadata defaults and the actual Copy/reopen/retry route pass in 0.7.8. Trip labels and canonical reconstruction pass in 0.7.9.
4. Implement on-demand descriptions and a recoverable batch queue. Use mocked service responses before a local LM Studio check.
5. Implement Google Photos delivery with injectable transport and durable membership. Prepare a concrete test-account flow before any account or delivery gate.
6. Verify the complete journey: camera plus phone → Walks/Trips → locations/descriptions → search → travel browsing → verified album delivery.

## Evidence and limits

The baseline had 190 passing tests. New failure tests initially failed against the existing implementation, including same-size corruption, partial import recovery and cleanup of incomplete archive copies. Astra reviewed the source repeatedly; a public-source-only Claude Opus consultation recommended forward recovery, staged copying, atomic index generations and schema-aware rewriting. Those recommendations are review input, not evidence that the app ran correctly.

The automated tests use temporary archives and injected failures. They do not establish actual OneDrive eviction, power-loss durability on every filesystem, Google Photos delivery, or native interface usability. Cooperative archive locking protects Walkfolio operations on this machine; it is not a distributed OneDrive lock.
