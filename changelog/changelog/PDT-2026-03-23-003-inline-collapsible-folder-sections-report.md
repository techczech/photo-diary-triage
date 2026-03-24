# PDT-2026-03-23-003 Inline Collapsible Folder Sections Report

## Summary Of What Changed

- Added a day-first inline browser for higher-level month/day browsing.
- Added inline review modes:
  - `Days`
  - `Days + Bursts`
  - `Days + Clusters`
  - `Days + Clusters + Bursts`
- Changed session opening so the app drops into the first useful photo-bearing level instead of stopping too high in the tree.
- Added single-day auto-expand and multi-day collapsed sections with tiny preview strips plus `Expand All` and `Collapse All`.
- Shipped this change as release `0.1.3` with feature slug `inline-folder-sections`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/BrowserModels.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- Verified the app bundle rebuilds with release metadata `0.1.3` / `inline-folder-sections`

## Known Gaps Or Follow-Up Items

- This item still needs user review in the running app.
- Follow-up specs already exist for adjustable grouping granularity and the right-hand details inspector.

## Shipped Release

- Version: `0.1.3`
- Feature slug: `inline-folder-sections`
