# PDT-2026-05-22-053: View And Triage Modes

## User Request Summary

The app should let a photowalk be viewed in the file system and inside the triage browser, with archive-library viewing treated as a different mode from triage. The default mode should be view-first. From that state, the user should be able to switch deliberately into triage, with camera/source triage and archive triage separated as different intents.

## Constraints

- Preserve existing file-system reveal/open behaviour.
- Preserve the SSD-first selective-import workflow.
- Do not make archive browsing look like source cleanup triage.
- Do not enable archive mutation unless the app state makes that safe and clear.
- Keep the selection process working as-is.
- Make the mode, current state, and next action visible without relying on the inspector alone.
- Follow a cognitive walkthrough lens: what can I do, what happens after I do it, and how do I know it worked?

## Implementation Intent

- Add an explicit app workspace mode for archive view, camera triage, and archive triage.
- Default the app to archive view.
- Make the browser roots reflect the selected mode instead of mixing current session and archive library in one tree.
- Show the current mode in the main browser header with plain next-action copy.
- Keep camera/source triage as the only import-selection mutation mode in this pass.
- Treat archive triage as a named, visible workflow state, but keep it read-only until archive mutation semantics are designed safely.

## Test Conditions

- App starts in archive view mode.
- Archive view sidebar shows archive library roots without a current-session section.
- Camera triage sidebar shows current-session roots without the archive library section.
- Switching modes clears stale review selection and lands on the correct browser root.
- Import selection mutation remains disabled outside camera triage.
- Existing review and sidebar tests continue to pass.

## Success Criteria

- The user can tell whether they are viewing the archive or triaging a source.
- The archive library can be browsed from the app without first pretending to open a camera/source triage session.
- Camera triage stays clearly separate from archive viewing.
- The app gives a clear next action for the selected mode.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.14
- APP_BUILD: 91
- APP_FEATURE_SLUG: view-and-triage-modes
