# PDT-2026-05-22-050 Copied Log Archive Link Report

## Item ID

- PDT-2026-05-22-050

## Summary

- Copied photo logs now keep showing the actual archive folder after copy verification.
- The inspector workflow now tells the user to open the archive folder, inspect the copied photos, then confirm backup.
- A new `Open Archive Folder` action is available in the copied-log workflow card, import action strip, and app command menu.
- Backup confirmation remains manual and source cleanup stays locked until backup confirmation when that safety setting is enabled.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Sources/PhotoDiaryTriage/WorkflowGuidanceResolver.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `APP_RELEASE.env`

## Verification

- `git diff --check`
- `swift test`
- `scripts/build_app_bundle.sh`
- Launched `dist/PhotoDiaryTriage.app`
- Verified bundle metadata reports `CFBundleShortVersionString=0.2.11`, `CFBundleVersion=88`, and `PDTLatestFeatureSlug=copied-log-archive-link`

## Known Gaps Or Follow-Up Items

- Opening the folder helps the user inspect copied files, but it does not confirm an independent/off-device backup by itself.
- Backup confirmation is still an explicit user action.

## Shipped Release

- APP_VERSION: 0.2.11
- APP_BUILD: 88
- APP_FEATURE_SLUG: copied-log-archive-link
