# PDT-2026-05-22-050 Copied Log Archive Link

## Item ID

- PDT-2026-05-22-050

## Title

- Copied log archive link

## User Request Summary

- When a photo log has been copied, the app should show where the copied photos are on disk.
- User needs to open that location inside the triage app before confirming backup.

## Constraints

- Preserve current copy, verify, backup confirmation, and cleanup behavior.
- Do not auto-confirm backup.
- Do not change selection, S/C/X, or photo-log membership semantics.
- Keep the link available after the copy operation has finished, not only during copy progress.
- Keep RAW companion work out of scope.

## Implementation Intent

- Derive the archive folder for copied logs from imported item destination paths.
- Keep the destination visible in copied/verified states.
- Add an `Open Archive Folder` action beside copy/backup/cleanup controls when the archive folder exists.
- Update workflow guidance so backup confirmation explicitly says to open the archive folder and inspect copied photos first.
- Add tests for copied-log archive destination and guidance.

## Test Conditions

- Unit tests for readiness destination after copy.
- Unit tests for workflow next action after copy.
- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.
- Launch rebuilt app and verify bundle release metadata.

## Success Criteria

- Copied logs show the archive folder path in the inspector.
- User can open that archive folder from inside the app before confirming backup.
- Backup confirmation remains manual.
- Release version is bumped and handoff names exact version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.11
- APP_BUILD: 88
- APP_FEATURE_SLUG: copied-log-archive-link
