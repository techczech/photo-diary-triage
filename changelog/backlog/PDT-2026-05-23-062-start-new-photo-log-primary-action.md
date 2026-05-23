# PDT-2026-05-23-062: Start New Photo Log Primary Action

## User Request Summary

- After copying from a photo log, the user feels stuck inside that log.
- Add a clear primary interface button to close the current photo log and start a new one.

## Constraints

- Preserve the SSD-first selective-import workflow.
- Do not make source cleanup easier or more automatic.
- Keep the action fast and obvious after copy.
- Reopen the matching source inbox when possible so the next photo log can be created from source decisions.
- Keep backlog, changelog, and release metadata aligned.

## Implementation Intent

- Add app-state support for closing the current photo log and returning to its source inbox.
- Prefer the saved inbox record for an immediate transition; fall back to source reload if needed.
- Surface `Start New Photo Log` as a prominent action in the copy/action strip for photo-log sessions.
- Update workflow copy so copied logs point to the new action.
- Add regression coverage for returning from a copied photo log to the matching source inbox.

## Test Conditions

- A copied/opened photo log exposes the start-new-log state action.
- Triggering the action opens the matching source inbox.
- The opened source inbox keeps remaining source photos visible for the next log.
- Existing copy, photo-log, and review tests continue to pass.

## Success Criteria

- `APP_VERSION=0.2.23`.
- `APP_BUILD=100`.
- `APP_FEATURE_SLUG=start-new-photo-log-primary-action`.
- After Copy in a photo log, the primary action strip includes `Start New Photo Log`.
- Clicking it closes the current photo log and returns to the source inbox for the same source folder.

## Current Status

- `approved_for_implementation`

## Target Release

- target version: `0.2.23`
- target build: `100`
- target feature slug: `start-new-photo-log-primary-action`
