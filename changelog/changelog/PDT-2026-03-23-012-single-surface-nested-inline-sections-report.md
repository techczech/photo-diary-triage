# PDT-2026-03-23-012 Single Surface Nested Inline Sections Report

## Summary Of What Changed

- Replaced the additive inline-browser layout with a single nested grouped review surface.
- Grouped modes now replace the flat grid instead of rendering a flat grid plus grouped sections underneath it.
- Photos now appear only in the deepest active section, with nested structures for:
  - `Day -> Photos`
  - `Day -> Burst -> Photos`
  - `Day -> Cluster -> Photos`
  - `Day -> Cluster -> Burst -> Photos`
- Preview-strip clicks now expand the relevant section path and reveal the chosen photo inside the main grouped surface.
- `Expand All`, `Collapse All`, and mode changes now operate across the current nested section structure.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserModels.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `changelog/backlog/PDT-2026-03-23-012-single-surface-nested-inline-sections.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- `codesign -vvv dist/PhotoDiaryTriage.app`
- verified the rebuilt bundle carries release metadata `0.1.10 / nested-inline-sections`

## Known Gaps Or Follow-Up Items

- This behavioral fix still needs user review in the running app.
- `swift test` remains blocked by the local macOS CLT/XCTest issue.
- Photos that do not belong to a burst or cluster are grouped into embedded `Other Photos` remainder sections instead of being dropped or duplicated.

## Shipped Release

- Version: `0.1.10`
- Feature slug: `nested-inline-sections`
