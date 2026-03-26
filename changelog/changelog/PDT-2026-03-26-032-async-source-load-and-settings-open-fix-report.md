# PDT-2026-03-26-032 Async Source Load And Settings Open Fix Report

- Item ID: `PDT-2026-03-26-032`
- Title: `Async source load and settings open fix`
- Shipped release version: `0.1.70`
- Shipped feature slug: `async-source-load-and-settings-open-fix`
- Status: `implemented`

## Summary

Moved source-folder scanning and grouping off the main actor so choosing a large source like `/Volumes/EOS_DIGITAL/DCIM` no longer blocks the app UI. Also replaced the sidebar settings action with SwiftUI’s direct settings opener and made changing the default source root immediately try to open the new source.

## Files Changed

- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/ContentViewSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewSections.swift)
- [Sources/PhotoDiaryTriage/StateSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/StateSupport.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-032-async-source-load-and-settings-open-fix.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-032-async-source-load-and-settings-open-fix.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Notes

- The source scan now runs in a detached task with a fresh scanner and grouping service, then publishes the rebuilt inbox back on the main actor.
- Changing the default source root now saves settings and immediately attempts to load from the new root instead of only updating the stored preference.
