# PDT-2026-03-23-011 Settings Window Reachability Follow-Up Report

## Summary Of What Changed

- Followed up on the failed `0.1.8` settings scroll fix by making the Settings window itself taller while keeping vertical scrolling enabled.
- Expanded the settings content to the full available width so lower controls are easier to reach.
- Shipped the follow-up as release `0.1.9` with feature slug `settings-window-fit`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `changelog/backlog/PDT-2026-03-23-011-settings-window-reachability-follow-up.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- verified the rebuilt app bundle carries release metadata `0.1.9 / settings-window-fit`

## Known Gaps Or Follow-Up Items

- This follow-up fix still needs user review in the running app.
- `swift test` remains blocked by the local macOS CLT/XCTest issue.

## Shipped Release

- Version: `0.1.9`
- Feature slug: `settings-window-fit`
