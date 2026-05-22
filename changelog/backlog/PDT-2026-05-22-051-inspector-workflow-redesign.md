# PDT-2026-05-22-051 Inspector Workflow Redesign

## Item ID

- PDT-2026-05-22-051

## Title

- Inspector workflow redesign

## User Request Summary

- The copied-log inspector still feels confusing and messy.
- The copied archive folder must be an obvious link inside the app.
- The experience should be redesigned around user intent, modern macOS patterns, and a cognitive walkthrough of each workflow stage.

## Constraints

- Preserve SSD-first selective import.
- Preserve manual backup confirmation.
- Preserve cleanup gating.
- Do not change S/C/X triage semantics or photo-log membership semantics.
- Keep the inspector fast and scannable.
- Use native SwiftUI/macOS controls and familiar Finder-oriented wording.
- Keep tracking, changelog, and release metadata aligned.

## Implementation Intent

- Move the workflow state to the top of the inspector.
- Replace the current state table with a task-focused workflow panel.
- Make the archive folder path a link-style control that opens the folder in Finder.
- Show the correct primary action for copy, archive review, backup confirmation, and source cleanup.
- Collapse lower-priority inspector content such as photo-log library and storage/source details.
- Add a design-planning record and cognitive-walkthrough notes.
- Update tests for copied/cleanup guidance and destination visibility.

## Cognitive Walkthrough Questions

- Will the user try to achieve the right next result?
- Will the user notice the correct action?
- Will the user associate the action with their goal?
- After using the action, will the user see that progress was made?

## Test Conditions

- Unit tests for copied-log and ready-cleanup workflow wording.
- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.
- Launch rebuilt app and verify bundle release metadata.

## Success Criteria

- Copied logs show a visible, clickable archive folder path at the top of the inspector.
- Backup confirmation and cleanup are presented as separate safe steps.
- The first inspector viewport focuses on workflow, current log, and the next action.
- Lower-priority details no longer dominate the inspector.
- Release version is bumped and handoff names the exact version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.12
- APP_BUILD: 89
- APP_FEATURE_SLUG: inspector-workflow-redesign
