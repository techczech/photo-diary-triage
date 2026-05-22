# PDT-2026-05-22-051 Inspector Workflow Redesign Report

## Item ID

- PDT-2026-05-22-051

## Summary

- Redesigned the inspector around the current workflow task instead of source metadata.
- Moved the workflow panel to the top of the inspector.
- Added a stage list for copy, archive review, backup confirmation, and source cleanup.
- Made the archive folder path a link-style control that opens the folder in Finder.
- Put the current log summary directly below workflow with compact metrics.
- Moved photo-log library and source/storage details behind collapsed disclosure rows.
- Fixed copied/cleanup wording so backup-confirmed logs no longer say they are waiting for backup confirmation.
- Added a design plan and cognitive-walkthrough record.

## Files Changed

- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorWorkflowViews.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Sources/PhotoDiaryTriage/WorkflowGuidanceResolver.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `design-plans/inspector-workflow-redesign/`
- `APP_RELEASE.env`

## Cognitive Walkthrough

- State recognition: workflow is first and names the current log state.
- Action visibility: the copied archive folder is a link-style row in the first workflow panel.
- Action association: the folder link opens Finder; backup confirmation remains a separate button.
- Progress feedback: guidance changes from copied/waiting to backup confirmed/cleanup ready.
- Final safety step: source cleanup remains a separate final action after backup confirmation.

## Verification

- `swift test`
- `git diff --check`
- JSONL validation for `changelog/backlog.jsonl`
- `scripts/build_app_bundle.sh`
- Launched `dist/PhotoDiaryTriage.app`
- Verified bundle metadata reports `CFBundleShortVersionString=0.2.12`, `CFBundleVersion=89`, and `PDTLatestFeatureSlug=inspector-workflow-redesign`

## Known Gaps Or Follow-Up Items

- The redesigned inspector clarifies source cleanup as a final step, but the cleanup action itself still deserves a dedicated confirmation pass.
- The image-to-design record includes a preserved prompt and design trace; the production artifact is the native SwiftUI implementation.

## Shipped Release

- APP_VERSION: 0.2.12
- APP_BUILD: 89
- APP_FEATURE_SLUG: inspector-workflow-redesign
