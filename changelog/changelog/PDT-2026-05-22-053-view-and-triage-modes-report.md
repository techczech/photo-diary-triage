# PDT-2026-05-22-053: View And Triage Modes Report

## Summary

The app now has explicit workspace modes:

- **Archive View**: the default. Shows the archive library only.
- **Camera Triage**: shows the current source/session only and keeps S/C/X import decisions enabled.
- **Archive Triage**: separate archive workflow state, currently read-only so archive mutation is not implied before it is safe.

The main browser now shows the current mode, a short state description, the next action, and an **Open in Finder** button for the selected browser folder. This connects the in-app archive/source browser to the same photowalk on disk.

## Files Changed

- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-22-053-view-and-triage-modes.md`

## Cognitive Walkthrough

- **Question: What state is the app in?** The header now names the active mode directly.
- **Question: What can I do next?** The header explains whether to choose an archive walk, open a source folder, or continue source triage.
- **Question: What happens after I act?** Switching modes rebuilds the sidebar around that intent instead of mixing archive and current-session roots.
- **Question: How do I confirm it worked?** The selected archive/source folder can be opened in Finder from the browser header, while the same walk can be viewed in the app.
- **Question: Can I accidentally change archive triage state?** No. Import selection mutation is enabled only in Camera Triage.

## Verification

- Ran `swift build`.
- Ran `swift test`; 102 tests passed.
- Built `dist/PhotoDiaryTriage.app`.
- Launched `dist/PhotoDiaryTriage.app`.
- Verified bundle metadata reports version `0.2.14` and build `91`.

## Known Gaps

- Archive Triage is intentionally read-only in this release. It is now a visible mode, but archive mutation semantics still need a separate design pass.
- This pass did not create generated bitmap mockups from the image-to-design workflow because the implementation was a targeted native SwiftUI change from existing screenshots, not a multi-direction visual mockup exploration.

## Shipped Release

- APP_VERSION: 0.2.14
- APP_BUILD: 91
- APP_FEATURE_SLUG: view-and-triage-modes
