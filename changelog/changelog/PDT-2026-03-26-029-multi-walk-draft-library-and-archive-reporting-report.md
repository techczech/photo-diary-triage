# PDT-2026-03-26-029 Multi-Walk Draft Library And Archive Reporting Report

- Item ID: `PDT-2026-03-26-029`
- Title: `Multi-walk draft library and archive reporting`
- Shipped release version: `0.1.67`
- Shipped feature slug: `multi-walk-draft-library-and-archive-reporting`
- Status: `implemented`

## Summary

Turned persisted sessions into a real walk-draft library. Source folders now open as resumable inbox sessions, selected photos can be split into saved walk drafts with exclusive ownership, the sidebar exposes those drafts for resume and inbox reopening, and committed walk manifests now record excluded-file and unresolved-decision reporting in addition to imported files.

## Files Changed

- [Sources/PhotoDiaryTriage/AppCommands.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppCommands.swift)
- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift)
- [Sources/PhotoDiaryTriage/ContentViewSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewSections.swift)
- [Sources/PhotoDiaryTriage/ImportCoordinator.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ImportCoordinator.swift)
- [Sources/PhotoDiaryTriage/ManifestRenderer.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ManifestRenderer.swift)
- [Sources/PhotoDiaryTriage/Models.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/Models.swift)
- [Sources/PhotoDiaryTriage/StateSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/StateSupport.swift)
- [Sources/PhotoDiaryTriage/UIState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/UIState.swift)
- [Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [Tests/PhotoDiaryTriageTests/TestSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/TestSupport.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-029-multi-walk-draft-library-and-archive-reporting.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-029-multi-walk-draft-library-and-archive-reporting.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Notes

- Existing persisted sessions without explicit `sessionKind` or `workspaceSourceFolder` decode as walk drafts tied to their source folder, preserving backward compatibility.
- Reopening an existing source inbox resumes the persisted unassigned media set; automatic rescanning and merge of newly-added source files is left for a follow-up if needed.
