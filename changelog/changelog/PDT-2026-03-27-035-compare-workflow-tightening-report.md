# PDT-2026-03-27-035 Compare Workflow Tightening Report

- Item ID: `PDT-2026-03-27-035`
- Title: `Compare workflow tightening`
- Shipped release version: `0.1.73`
- Shipped feature slug: `compare-workflow-tightening`
- Status: `implemented`

## Summary

Tightened compare into a denser decision mode. Compare now opens at two columns by default for any multi-item compare set, uses a slimmer per-card action layout, adds a compare-only `Q` shortcut for removing the focused item from compare, prunes excluded items from compare immediately, and keeps focus plus scroll continuity when compare navigation or triage actions advance to a new item.

## Files Changed

- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift)
- [Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift)
- [Sources/PhotoDiaryTriage/UIState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/UIState.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-27-035-compare-workflow-tightening.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-27-035-compare-workflow-tightening.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps / Follow-up

- The compare scroll targeting uses a dedicated pending target in compare state, but there is still a macOS 14 deprecation warning on one SwiftUI `onChange` call that can be cleaned up separately without changing behavior.
