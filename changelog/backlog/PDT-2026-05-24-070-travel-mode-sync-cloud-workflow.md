# PDT-2026-05-24-070: Travel mode sync and cloud workflow

## User Request Summary

- Research how PhotoDiaryTriage should support travel use on a small-drive MacBook.
- Triage directly from SD card while keeping SD card files as backup.
- Copy selected photos to a OneDrive-backed archive when the machine has limited local storage.
- Keep photo/photo-log state syncable between machines.
- Handle cloud-placeholder or not-fully-synced archive files gracefully.
- Consider optional reduced-quality Google Photos upload if there is an easy safe route.
- Clarified: OneDrive is the intended travel copy/backup path. Files copied locally into OneDrive should normally upload to OneDrive cloud and then sync back to the main Mac.
- Clarified: travel workflow is JPEG-first. RAW companion support should remain optional and low-priority.
- Clarified: keep travel copies inside the existing OneDrive `Pictures` archive, not a separate staging archive.
- Clarified: OneDrive absolute root differs by machine, but relative paths inside `Pictures` should stay stable across machines.

## Constraints

- Preserve SSD/SD-card-first selective import workflow.
- Do not assume the travel machine has enough free local disk for a full archive.
- Source cleanup must stay unavailable or clearly discouraged for SD-card travel mode.
- State sync must focus on selected photo/log state, not broad app state or live SQLite sync.
- State sync must avoid corrupting app sessions when two machines diverge.
- Cloud-storage handling must distinguish local files, cloud placeholders, missing files, and evicted files.
- OneDrive copy verification can confirm local destination bytes; OneDrive upload/sync confirmation must be represented separately unless there is reliable local evidence.
- State records must store both machine-local absolute paths and OneDrive-relative archive paths, with OneDrive-relative paths treated as canonical for cross-machine matching.
- Google Photos upload must not become a hard dependency for core triage.

## Implementation Intent

- First slice:
  - Add an app setting for workflow role: main archive machine or travel machine.
  - Add an app setting for the canonical OneDrive `Pictures` root.
  - Store OneDrive/Pictures-relative archive paths for copied files and logs.
  - Keep absolute paths as machine-local hints only.
  - Keep travel mode JPEG-first and RAW companions opt-in.
  - Keep source cleanup disabled or blocked for travel-machine copied items.
- Later slices:
  - Add richer OneDrive sync/locality state.
  - Add conflict-aware state import/discovery between machines.
  - Add Google Photos reduced-JPEG CLI handoff.

## Test Conditions

- Test with SD-card-like source path and OneDrive CloudStorage archive path.
- Test the same OneDrive-relative archive path with two different simulated OneDrive absolute roots.
- Test low-free-space warning behavior.
- Test copied file verification when destination exists locally.
- Test JPEG-only travel copy path with RAW companions disabled by default.
- Test archive/log visibility when destination files are unavailable or cloud-only.
- Test backup export/import or sync round-trip between two app-support roots.

## Success Criteria

- User can triage on travel Mac without copying the full SD card locally.
- Selected photos can be copied into OneDrive-managed storage with clear copy/upload/locality status.
- Photo logs can move between machines without ambiguous ownership or silent data loss.
- Main Mac can remap travel-created records from MacBook OneDrive absolute paths to its own OneDrive `Pictures` root.
- Main machine can resume from travel-created logs.
- Google Photos reduced-quality route is clearly classified as built-in, external handoff, or deferred.
- SD card remains treated as retained source backup after OneDrive copy.

## Current Status

- status: awaiting_user_review
- target release version: 0.2.29
- target feature slug: `travel-mode-sync-cloud-workflow`
