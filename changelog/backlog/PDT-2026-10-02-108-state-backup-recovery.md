---
item_id: PDT-2026-10-02-108
title: Complete snapshots and recoverable app-state backup restoration
status: shipped_pending_native_acceptance
target_release_version: 0.7.12
target_build: 148
target_feature_slug: state-backup-recovery
source: Original PRD app-state backup requirement and independent reliability authorisation
---

# App-state backup recovery

The full-scope audit found that an export can omit a recent debounced decision, while a failed restore can publish new settings with old sessions or report success after a settings write failure. Empty restores can retain an old active session. Fix the existing export/import controls without changing archive content or uploading anything.

## Constraints and implementation

Drain pending writes through a throwing path; export a strict complete snapshot, refusing corrupt rows or database read errors. Validate duplicate identities and broken group references before any restore writes. Preserve precise dates in new backups and read existing ISO8601 backups. Recheck active work and recorded Copies after the file picker returns.

Restore sessions and settings with a durable before-image journal. Before the commit marker, restore both stores on failure or next launch. After that marker, never undo the completed restore because journal removal failed. Block normal writes if recovery fails; retain evidence and offer retry rather than deleting support data. Publish memory only after durable commit, clear obsolete active/selection state on an empty restore, and invalidate old asynchronous source/archive/provider work.

## Tests and success criteria

Exercise actual SQLite transaction failure and corrupt/locked reads, immediately exported decisions, pending-save failure, duplicate identities, legacy dates and precise new dates, empty restore, active/recorded Copy guards, settings/session write failures, failed rollback, prepared/committed startup recovery and post-commit cleanup failure. Rebuild and verify the closed app bundle. Native file-picker acceptance remains on the consolidated return check. A success message means both persistent stores contain the imported snapshot.

Independent development is authorised by Dominik's current request; the existing backup controls and original requirement define the scope. Astra reviews the recovery boundary. No further permission or live private data is needed for fixture development.

## Result

Implemented in 0.7.12 build 148. All 384 tests pass, including 34 new backup/recovery
regressions. Astra's final focused source review is clear. See the implementation report;
native picker and full real-provider acceptance remain explicit.
