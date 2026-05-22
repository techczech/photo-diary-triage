# PDT-2026-05-22-047 Photo Log Copy Continuation

## Item ID

- PDT-2026-05-22-047

## Title

- Photo log copy continuation

## User Request Summary

- User had already made selections into a triage/photo log.
- User wants to continue that work and copy selected files to disk.
- Current buttons feel broken or leave no clear instruction about what to do next.

## Constraints

- Preserve SSD-first selective-import workflow.
- Preserve distinct meanings of `Edit Items` and `Edit Details`.
- Keep keyboard-driven triage behavior intact.
- Do not broaden into RAW companion redesign.
- Do not make copy actions destructive or automatic.

## Implementation Intent

- Make existing photo-log rows use clearer action wording for continuing selection work.
- Explain disabled photo-log item editing when a log has already been copied or cleaned.
- Make copy readiness messages tell the user how to continue an existing log and what must happen before files can be copied.
- Keep copy buttons gated, but make the gating visible and understandable.

## Test Conditions

- Unit tests for copy readiness messages in undecided, no-copy, and already-imported states.
- Unit tests for imported photo logs being blocked from membership editing.
- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.

## Success Criteria

- User can identify the right action to continue a previous photo log.
- Copy-to-disk controls state why they are unavailable.
- Existing imported or cleaned logs do not appear silently broken.
- Release version is bumped and handoff names the exact app version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.8
- APP_BUILD: 85
- APP_FEATURE_SLUG: photo-log-copy-continuation
