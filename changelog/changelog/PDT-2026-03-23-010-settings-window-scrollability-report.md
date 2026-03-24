# PDT-2026-03-23-010 Settings Window Scrollability Report

## Summary Of What Changed

- Fixed the Settings window so its contents scroll vertically instead of clipping lower controls.
- Preserved the existing settings layout while making the grouping and backup sections reachable on a normal display.
- Shipped the fix as release `0.1.8` with feature slug `settings-scrollability`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `changelog/backlog/PDT-2026-03-23-010-settings-window-scrollability.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- verified the packaged bundle was rebuilt with release metadata `0.1.8 / settings-scrollability`

## Known Gaps Or Follow-Up Items

- This fix still needs user review in the running app.
- `swift test` remains blocked in this environment by the local macOS CLT/XCTest issue.

## Shipped Release

- Version: `0.1.8`
- Feature slug: `settings-scrollability`
