---
item_id: PDT-2026-10-02-100
title: Walkfolio archive reliability and completion goals
shipped_release_version: 0.7.4
shipped_build: 140
shipped_feature_slug: archive-reliability
status: shipped_pending_native_check
---

# Walkfolio 0.7.4: archive recovery and trustworthy records

Import now records an immutable destination plan before copying, stages each copy, verifies SHA-256 and checkpoints per-file progress. A failed copy or manifest write can resume without creating another suffixed copy. A retry rejects changed selections, source configuration or backup consent. Canonical photo manifests retain the imported digest.

Cleanup rechecks the complete selected JPEG/RAW set against the import digest before deleting any source. Per-source deletion records make partial cleanup resumable; a missing or changed archive copy retains remaining sources. Backup and main-machine checks apply inside the service.

Canonical metadata edits preserve unknown fields and independent Walk values. Longer titles/locations and notes can change together. Appended imports reserve photo-manifest stems across extensions, retain previous Walk membership/text and append session events. Coordinates survive reconstruction after index deletion and archive relocation.

Moves and migration prepare recoverable plans before mutation, preserve canonical identity and text, and revalidate identity/path boundaries on retry. Destination collisions rename structural manifests and logs consistently. Same-Trip moves do nothing. Historical lookalikes, hidden material, external crop provenance and escaping symlinks are protected. Trip identity/title/custom sections survive membership changes; unreadable remaining members abort date recomputation. Saved Photo Logs resolve moved photos by canonical media identity, including return moves and path reuse. Original media renames use filesystem identity without opening their bytes.

Index replacement publishes a staged complete generation through one atomic pointer; its expected shard hashes detect incomplete synchronisation. A failed rebuild preserves the prior generation, and full rebuild can repair a broken pointer. Delayed import thumbnail work re-reads current canonical metadata. Thumbnail failures/cancellation still attempt eviction of newly hydrated originals; unknown availability denies implicit byte reads. Session backup replacement is transactional.

## Files changed

- ImportCoordinator, ArchivePlanner, ArchiveOperationRecovery, ArchiveFolderRecovery, ArchiveManifestEditor, ArchiveSessionPathReconciler and ArchiveTypedSidecarRewriter.
- ArchiveIndex, ArchiveCatalogue, ArchiveLayoutMigrator, WalkTripServices, Models, ManifestRenderer, SessionStore and AppState.
- ArchiveReliabilityTests and ArchiveMoveReliabilityTests; existing import/index/move/migration fixtures.
- APP_RELEASE.env, build_app_bundle.sh, README, development plan and tracking records.

## Verification

- Baseline: 190 tests passed. The first nine fault tests failed against the original code; failures covered corrupt copies, incomplete cleanup sets, interrupted imports and transaction failure.
- Final serialised test run: **225 tests in two suites passed in 11.333 seconds**. There are 35 additional regression tests.
- Large deterministic import: 128 files × 256 KiB, 0.275 seconds and 306,465 recovery bytes. This measures local copy/recovery behaviour; it is not a benchmark of OneDrive or decoded-image triage.
- Astra performed repeated read-only source reviews; concrete findings were converted into tests and fixes. Claude Code returned a public-source-only review using `claude-opus-5-5`; model reviews do not count as execution evidence.
- The real 0.7.4 build 140 bundle was packaged and ad-hoc signed. Packaging queries Swift's actual binary location, supporting the installed toolchain's changed build layout.
- Built/installed release metadata, binary equality and strict deep signature verification were checked. Installation retained the previous real bundle and did not launch the interface.

## Remaining completion work

The [development plan](../../planning/development-plan-walkfolio-reliability.md) retains the complete approved 1.0 scope. Index-only travel browsing/grid loading is next; archive-wide Map and complete overrides, LM Studio descriptions/provenance/queue, Google Photos upload/membership and historical title/date harvesting remain unfinished.

Native usability, actual OneDrive hydration/eviction and power-loss behaviour were not established by these tests. Tests used temporary archives; no live photo archive was migrated or cleaned. The archive lock is cooperative and local, not a distributed OneDrive lock. A short native check is recorded separately for the reviewer's return; development continues independently.
