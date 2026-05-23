# PDT-2026-05-23-060: Global Responsiveness Speed Report

## Summary

Improved perceived responsiveness across archive browsing, review state updates, sidebars, and photo opening in the post-`v0.2.20` build.

Archive view was the clearest hot path. Loading a walk folder now uses file attributes only instead of full image metadata extraction, so even a tiny archive folder no longer waits on ImageIO metadata reads before the list can appear. The archive browser tree is also cached until the archive root or archive contents change.

Review snapshots now avoid building grouped day-section payloads while the normal flat review grid is active. Source photo-log ownership is cached across repeated sidebar and review refreshes, and proposed photo-log planning is skipped while browsing the archive.

Full photo preview and compare now show cached thumbnail placeholders while the full interactive display image decodes. This keeps opening photos from feeling blank or stalled when the full image decode is still in progress.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/FileScanner.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `changelog/backlog/PDT-2026-05-23-060-global-responsiveness-speed.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- Ran `swift test`: 111 tests passed.
- Built the packaged app with `./scripts/build_app_bundle.sh`.
- Launched `dist/PhotoDiaryTriage.app` successfully.
- Used Computer to confirm the running app connection, then used macOS accessibility automation to exercise the live window.
- Captured live latency logs from the fresh packaged app:
  - sidebar toggles: `101.27ms`, `82.06ms`
  - inspector toggles: `44.09ms`, `57.74ms`, `41.49ms`
- Added tests proving:
  - archive browser trees are reused until invalidated
  - archive media load uses the fast file-attribute scan path
  - flat review snapshots defer grouped-section payloads until grouped review opens

## Known Gaps

- The Computer connector exposed only the remote app connection in this session, so the detailed live clicks were driven through macOS accessibility automation.
- The archive fast path deliberately uses file modification date rather than EXIF capture date while browsing existing archive folders. Source ingest still uses full metadata.

## Shipped Release

- APP_VERSION: 0.2.21
- APP_BUILD: 98
- APP_FEATURE_SLUG: global-responsiveness-speed
