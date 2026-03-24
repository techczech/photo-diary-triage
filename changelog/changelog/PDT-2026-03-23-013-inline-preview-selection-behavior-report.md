# PDT-2026-03-23-013 Inline Preview And Selection Behavior Report

## Summary Of What Changed

- Changed collapsed inline preview strips to use representative sampling instead of only the first few photos.
- In burst-aware sections, preview strips now prefer one representative image per burst before filling remaining slots.
- Changed preview-strip clicks to expand/select/reveal the photo in the grouped surface instead of opening the full-photo popup.
- Changed the expanded grouped inline grid so single click selects and double click opens the full-photo preview.
- Follow-up build `0.1.12` hardened the grouped-grid tap handling to clear stale preview state on single click and use an explicit exclusive double-click path for preview opening.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `changelog/backlog/PDT-2026-03-23-013-inline-preview-selection-behavior.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- verified the rebuilt app bundle carries release metadata `0.1.12 / inline-grid-single-click-fix`

## Known Gaps Or Follow-Up Items

- This interaction fix still needs user review in the running app.
- `swift test` remains blocked by the local macOS CLT/XCTest issue.

## Shipped Release

- Version: `0.1.12`
- Feature slug: `inline-grid-single-click-fix`
