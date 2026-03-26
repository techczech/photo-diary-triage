# PDT-2026-03-26-028 Candidate Triage State And RAW Promotion Report

- Item ID: `PDT-2026-03-26-028`
- Title: `Candidate triage state and RAW promotion`
- Shipped release version: `0.1.66`
- Shipped feature slug: `candidate-triage-state-and-raw-promotion`
- Status: `implemented`

## Summary

Added a first-class `Candidate` triage state across review, compare, filters, and commands, and changed RAW toggling so enabling RAW companions also promotes the item to included import state. This gives the review flow a new intermediate decision state while keeping RAW tied to actual import selection.

## Files Changed

- [Sources/PhotoDiaryTriage/AppCommands.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppCommands.swift)
- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/BrowserModels.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/BrowserModels.swift)
- [Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift)
- [Sources/PhotoDiaryTriage/ContentReviewItemViews.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentReviewItemViews.swift)
- [Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift)
- [Sources/PhotoDiaryTriage/Models.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/Models.swift)
- [Sources/PhotoDiaryTriage/SessionMutationCoordinator.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/SessionMutationCoordinator.swift)
- [Sources/PhotoDiaryTriage/UIState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/UIState.swift)
- [Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-028-candidate-triage-state-and-raw-promotion.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-028-candidate-triage-state-and-raw-promotion.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Notes

- Legacy sessions using `selected` and `skipped` still decode correctly, and the new `candidate` state now round-trips as a current value.
- Compare remains available through the existing button and `Cmd-Shift-C`; the single-key `C` path is now reserved for candidate triage.
