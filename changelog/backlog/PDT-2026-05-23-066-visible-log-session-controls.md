# PDT-2026-05-23-066: Visible log session controls

## User Request Summary

- Add a clearly visible control near the current log information.
- The active photo log must be saveable/renameable and stoppable from that area.
- A functional control to start a new logging session is mandatory.
- The user must be able to save, open, and start a new logging session from anywhere relevant, without getting trapped in one photo log.

## Constraints

- Put the controls where current log/session information is already shown.
- Do not rely on hidden menus or a distant photo-log tab for the escape path.
- Preserve the SSD-first selective-import workflow.
- Do not make photo selection depend on being in the Photo Logs library tab.
- Keep destructive source cleanup unchanged.

## Implementation Intent

- Add a visible current-log control cluster to the inspector's Current Log section.
- Let an active photo log save metadata and return to the source inbox in one clear action.
- Let an inbox start/create the next photo log from the same current-log control area when eligible.
- Provide an always visible Open Logs action from the same area.
- Keep the existing library and command actions wired to the same state methods.

## Test Conditions

- Verify a current photo log can return to the source inbox and clear the import operation.
- Verify the same action remains available when the user is viewing the Photo Logs mode.
- Verify an inbox with eligible marked photos can present the photo-log creation sheet from the current-log controls.
- Run the Swift test suite.
- Build the packaged app bundle.

## Success Criteria

- Current Log info visibly exposes Save Details, Open Logs, and Start New Log/Start Next Log controls.
- Start New/Next Log is functional from an active photo log and returns to the source inbox for further selection.
- Starting a log from an inbox remains available when there are marked photos to place in a log.
- App release metadata names the shipped version for testing.

## Current Status

- status: approved_for_implementation
- target release version: `0.2.26`
- target feature slug: `visible-log-session-controls`
