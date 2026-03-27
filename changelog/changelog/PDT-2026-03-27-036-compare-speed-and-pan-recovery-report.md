# PDT-2026-03-27-036 Compare Speed And Pan Recovery Report

- Item ID: `PDT-2026-03-27-036`
- Title: `Compare speed and pan recovery`
- Shipped release version: `0.1.74`
- Shipped feature slug: `compare-speed-and-pan-recovery`
- Status: `implemented`

## Summary

Removed the extra compare scroll-target state that was forcing redundant compare invalidation on focus moves, and switched compare auto-scroll back to a derived focused-item target. This keeps the compare sheet responsive while preserving automatic scroll-to-focus behavior. The compare keyboard layer now also forwards compare-only `Q` correctly, adds `H/J/K/L` pan commands for zoomed compare images, and restores non-autohiding compare scrollers so zoomed detail inspection is usable again.

## Files Changed

- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift)
- [Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift)
- [Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift)
- [Sources/PhotoDiaryTriage/UIState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/UIState.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-27-036-compare-speed-and-pan-recovery.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-27-036-compare-speed-and-pan-recovery.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps / Follow-up

- This recovery removes the redundant compare invalidation path and restores compare pan controls, but the speed improvement still needs your manual feel check against the previous slow behavior on real compare sessions.
