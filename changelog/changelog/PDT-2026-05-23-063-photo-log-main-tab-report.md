# PDT-2026-05-23-063: Photo log main tab report

## Summary

- Added Photo Logs as a main workspace mode beside Camera Triage and Archive Triage.
- Moved the photo-log list and controls into the main content area for that mode.
- Kept Create Photo Log visible in Photo Logs mode and tied to current source-triage decisions.
- Removed the photo-log library disclosure from the inspector so log controls are not duplicated in side surfaces.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentPhotoLogLibraryViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `changelog/backlog/PDT-2026-05-23-063-photo-log-main-tab.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test`
- `./scripts/build_app_bundle.sh`
- Launched `dist/PhotoDiaryTriage.app`

## Known Gaps Or Follow-Up Items

- Visual polish can be tuned after testing with real log counts and long log names.

## Release

- shipped release version: `0.2.24`
- shipped build: `101`
- shipped feature slug: `photo-log-main-tab`
