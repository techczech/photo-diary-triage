# PDT-2026-05-28-084 responsiveness and Computer check report

item_id: PDT-2026-05-28-084
status: implemented
shipped_release_version: 0.2.40
shipped_feature_slug: responsiveness-computer-check

## Summary

The final crop-repair build includes a small responsiveness pass for the shared AppKit image canvas, then was built, installed, launched, and visually checked as the installed `/Applications` app.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `changelog/backlog/PDT-2026-05-28-084-responsiveness-and-computer-check.md`

## User-Visible Behavior

- The installed app reports `v0.2.40 • responsiveness-computer-check`.
- Preview and compare image canvases avoid relayout and crop-rect republish work when SwiftUI sends unchanged image/zoom state.
- Canvas layout no longer publishes the same visible-crop geometry twice during layout.
- The installed app launches from `/Applications/PhotoDiaryTriage.app`.

## Verification

- `swift build` passed.
- `./scripts/build_app_bundle.sh` passed.
- Installed bundle metadata:
  - `CFBundleShortVersionString=0.2.40`
  - `CFBundleVersion=117`
  - `PDTLatestFeatureSlug=responsiveness-computer-check`
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app` passed.
- `pgrep -fl PhotoDiaryTriage` showed the installed executable running from `/Applications`.
- System Events reported one `Photo Diary Triage` window.
- Screenshot verification showed the running app with the release marker visible in the sidebar.

## Computer Use Result

Computer Use was invoked as requested, but `get_app_state` returned only `remoteConnection` for both `PhotoDiaryTriage` and `/Applications/PhotoDiaryTriage.app`.
Follow-up Computer Use click attempts were rejected because the Computer Use session did not become active.

Because of that tool limitation, the final live UI check used System Events plus screenshot inspection instead of a Computer Use accessibility tree.

## Known Gaps

- Computer Use did not provide an accessibility tree in this run.
- Manual testing should focus on actual crop gestures: visible crop, drag crop, crop/original switching, Command-scroll zoom, pinch zoom, and click-drag panning.
