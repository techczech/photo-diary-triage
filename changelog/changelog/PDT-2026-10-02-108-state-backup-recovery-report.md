---
item_id: PDT-2026-10-02-108
title: Complete app-state snapshots and recoverable restore
status: shipped_pending_native_acceptance
release_version: 0.7.12
build: 148
feature_slug: state-backup-recovery
---

# Complete backups and recoverable restore

Export now drains all pending decisions, retaining independent writes and failures when
switching between saved sessions. Strict snapshots refuse corrupt rows, interrupted SQLite
reads or malformed settings rather than silently omitting them. New versioned backups
retain precise dates and legacy session classification; existing ISO8601 backups remain
readable. Structural validation rejects duplicate identities and missing photo/Source
references without requiring historical volumes to be available.

Restore journals the complete before-image before changing either store. A prepared restore
rolls both stores back on failure or next launch; a committed restore survives journal
cleanup failure. Failed recovery retains its evidence, gates ordinary writes and offers
Retry Recovery. Successful retry uses strict validated publication, clears empty state and
never resurrects an old active session. Production RAM fallback cannot report a durable
backup success. Existing native backup controls remain in place.

Restoration rechecks active work and recorded Copies after the picker; source cleanup is
tracked before starting. Old editor selections, provider queues, source/archive tasks and
explicit byte grants are invalidated, including same-root restores. Synchronous session
changes drain pending writes so deletion cannot be undone by an old debounce. Multi-Source
membership operations retain provenance and update the Photo Log/Inbox in one SQLite
transaction.

## Files changed

- BackupStore, new BackupRestoreCoordinator, AppState, StateSupport, SessionStore,
  SettingsStore and SessionLifecycleCoordinator: strict export, recoverable transaction,
  guards, ordered writes and publication.
- Models and ContentView: legacy classification round-trip and Retry Recovery action.
- New BackupRecoveryTests: 34 meaningful failure/workflow regressions.
- Release metadata, PRD, planning and completion tracking: 0.7.12/build 148, full requirement
  evidence, original Map approval and default-Trip summary reconciliation.

## Verification

All 384 tests pass in 17.012 seconds (`/private/tmp/walkfolio-backup-full-tests.log`). Includes
actual SQLite trigger rollback, corrupt/locked reads, pending-save failure, two-session
rapid export, edit/delete/export, legacy precision, ambiguous marker sync, failed rollback,
prepared/committed reopen, empty recovery retry, production fallback, suspended source
cleanup and multi-Source transfer. Astra reviewed the restore boundary and corrected
material races; final focused source rereview is clear.

Bundle built and signed without launch. Installed 0.7.12 build 148 while closed; strict
deep signature verification passed and the installed executable matches the built bytes.
Previous app retained at `/private/tmp/Walkfolio-before-state-backup-0.7.12.app`.
Build log: `/private/tmp/walkfolio-backup-bundle.log`.
No live archive operation, provider authentication or private delivery ran. Native backup
pickers and original whole-app/provider acceptance remain in the consolidated exact-version
return check. Fixture durability does not certify every filesystem against physical power
loss. Cooperative application state is not a distributed OneDrive transaction.
