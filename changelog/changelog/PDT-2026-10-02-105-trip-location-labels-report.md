---
item_id: PDT-2026-10-02-105
title: Canonical Trip location labels and member preservation
shipped_release_version: 0.7.9
shipped_build: 145
shipped_feature_slug: trip-location-labels
status: shipped_pending_native_check
---

# Walkfolio 0.7.9: Trip labels survive reconstruction

A recognised Trip displays its derived Walk location label and allows a label-only override. Edit label saves a single canonical owned header; Use Walk locations clears it. Captured path, identity and expected label prevent selection changes or stale views from editing another Trip. The save preserves human notes, unknown sections, public titles and member order. Historical folders require verified canonical Walks before first Trip creation; copied stale Walk headers and linked ancestors are refused.

Default month Trips now receive canonical identities and membership just as named Trips do. Imports and moves update both affected records without losing labels. First-record creation discovers existing canonical Walks. Index generations carry Trip identity and label overrides, reconstruct after relocation and work in a fresh Travel root containing only the index. Travel saves update the current projection and targeted tiny canonical manifests; other index-only views await main publication.

Legacy migration snapshots complete final Trip manifests before any Walk moves, preserving identity, labels, member order, dates, notes and unknown sections. Same-month path replacements retain positions and already-modern members. Cross-month transfers include pre-existing canonical destination Walks and every planned rename. A conflicting canonical destination stops the whole operation before moves; interruption between verified destination write and legacy deletion resumes. Fresh migration rejects existing import/move/metadata recovery before creating its journal; pending migration blocks conflicting imports and moves.

## Files changed

TripLocationEditor adds contained atomic canonical editing, owned header/member patching and derived projection. Models/ManifestRenderer/TripManifestStore add the optional label and canonical default month identity. ArchiveIndex/ArchiveCatalogue and location projection carry current labels. AppState and ArchiveBrowserViews capture targets and expose contextual controls. ImportCoordinator, WalkMover and ArchiveLayoutMigrator coordinate membership and recovery. TripLocationTests covers actual AppState saves, canonical reconstruction and injected failures. README/development plan record the completion boundary.

## Verification

- All 297 tests in two suites passed in 13.262 seconds, up from 279. Parameterised default/named and main/Travel cases are included.
- Quoted/non-English labels, clear/fallback, unknown fields, earlier human sections, stale identity/label, atomic failure and written-response retry pass.
- AppState keeps a captured first Trip target while the view changes to another. Travel leaves index bytes unchanged and originals blocked.
- First month record, appends, source/destination moves, root relocation and fresh index-only Travel reconstruction retain labels and membership.
- Old/new mixed months, reverse manual ordering, unchanged modern members, occupied destinations, interruption/retry and competing import/move exclusion pass.
- A previous unfinished import remains resumable after a new migration is rejected; no conflicting migration journal is created.
- Astra repeatedly reviewed these cases; reported P1/P2 issues were corrected with regression coverage.
- Packaged and installed 0.7.9 build 145 while the app was closed. Strict deep signature verification and built/installed executable equality passed. Previous bundle retained at `/private/tmp/Walkfolio-before-trip-labels-0.7.9.app`.
- No native UI launch, live archive migration/rebuild, original hydration or real-photo publication was performed.

## Limits and next work

Native label controls and actual OneDrive behaviour remain separately reviewable. Cooperative locking is local, not a distributed OneDrive lock. An occupied independent canonical destination Trip is retained and migration refuses to merge its identity automatically. On-demand LM Studio descriptions and Google Photos delivery remain approved implementation work.
