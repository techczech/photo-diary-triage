# PDT-2026-05-22-048 Workflow State Guidance

## Item ID

- PDT-2026-05-22-048

## Title

- Workflow state guidance

## User Request Summary

- Selection works well.
- Photo-log creation, copying, backup confirmation, and cleanup feel opaque.
- App should clearly show current state, what is happening, and what to do next.

## Constraints

- Preserve existing selection mechanics.
- Preserve SSD-first selective-import workflow.
- Keep `Edit Items` distinct from `Edit Details`.
- Keep RAW companion redesign out of scope.
- Avoid static instructional clutter; guidance should reflect current app state.

## Implementation Intent

- Add a live workflow guidance snapshot to app state.
- Show the workflow state in the sidebar status area and inspector.
- Make copy/log creation phases explicit: source inbox, ready to create log, photo log in progress, ready to copy, copying, backup confirmation, source cleanup, archive browsing, and failures.
- Add regression tests for key workflow guidance states.

## Test Conditions

- Unit tests for source inbox, photo-log no-`S`, ready-to-copy, backup, cleanup, copying, failed, and archive-browsing guidance.
- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.
- Launch rebuilt app and verify bundle release metadata.

## Success Criteria

- User can always see what state the app is in.
- User can see whether the app is waiting, copying, ready to create a log, ready to copy, waiting for backup confirmation, or ready for cleanup.
- User gets one concrete next action tied to the current state.
- Release version is bumped and handoff names exact version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.9
- APP_BUILD: 86
- APP_FEATURE_SLUG: workflow-state-guidance
