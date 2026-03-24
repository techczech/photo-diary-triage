# PDT-2026-03-23-014 Inline Grid Double-Click Preview Report

## Summary Of What Changed

- Replaced the grouped inline grid’s SwiftUI tap-combination handling with an explicit macOS click target.
- Restored deterministic double-click preview opening without regressing the single-click-select behavior.
- Shipped the follow-up as release `0.1.13` with feature slug `inline-grid-double-click`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `changelog/backlog/PDT-2026-03-23-014-inline-grid-double-click-preview.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- verified the rebuilt app bundle carries release metadata `0.1.13 / inline-grid-double-click`

## Known Gaps Or Follow-Up Items

- This follow-up fix still needs user review in the running app.
- `swift test` remains blocked by the local macOS CLT/XCTest issue.

## Shipped Release

- Version: `0.1.13`
- Feature slug: `inline-grid-double-click`
