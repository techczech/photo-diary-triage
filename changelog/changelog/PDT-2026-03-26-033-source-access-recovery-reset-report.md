# PDT-2026-03-26-033 Source Access Recovery Reset Report

- Item ID: `PDT-2026-03-26-033`
- Title: `Source access recovery reset`
- Shipped release version: `0.1.71`
- Shipped feature slug: `source-access-recovery-reset`
- Status: `implemented`

## Summary

Completed the source-recovery reset so the app can compile and reliably prefer the live SSD inbox again. Source loading now uses a consistent default-root resolver, cancels stale background scans before direct session switches, surfaces explicit source-workspace state in the sidebar, and preserves legacy-session compatibility without letting old inbox records or drafts steal ownership of the active source.

## Files Changed

- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/BrowserViewModel.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/BrowserViewModel.swift)
- [Sources/PhotoDiaryTriage/ContentViewSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewSections.swift)
- [Sources/PhotoDiaryTriage/Models.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/Models.swift)
- [Sources/PhotoDiaryTriage/SessionLifecycleCoordinator.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/SessionLifecycleCoordinator.swift)
- [Sources/PhotoDiaryTriage/StateSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/StateSupport.swift)
- [Sources/PhotoDiaryTriage/UIState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/UIState.swift)
- [Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [Tests/PhotoDiaryTriageTests/StateSupportTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/StateSupportTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-033-source-access-recovery-reset.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-033-source-access-recovery-reset.md)

## Verification

- `swift test`
- `swift build`
- `./scripts/build_app_bundle.sh`

## Known Gaps / Follow-up

- Manual launch-time verification on the real `/Volumes/EOS_DIGITAL` SSD is still required to confirm the intended live-source-first behavior in the packaged app.
