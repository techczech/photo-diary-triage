# PDT-2026-03-24-020 Browser View Model Extraction Report

## Summary Of What Changed

- Extracted browser and archive tree construction out of `AppState.swift` into a dedicated [BrowserViewModel.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/BrowserViewModel.swift) helper.
- Moved browser root generation, node-map construction, preferred initial sidebar selection, archive node building, and archive folder scanning into the new helper.
- Updated `AppState` to delegate browser concerns while keeping published state, cache ownership, thumbnail requests, and status messaging in place.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/BrowserViewModel.swift`
- `changelog/backlog/PDT-2026-03-24-020-browser-view-model-extraction.md`

## Verification Performed

- `swift build`
- confirmed `AppState.swift` dropped from 1660 lines to 1322 lines

## Known Gaps Or Follow-Up Items

- `AppState.swift` is still the largest file in the repo and still owns inline-section organization, auto-load flow, and various persistence/UI coordination concerns.
- `swift test` remains deferred until full Xcode is installed.
- This extraction isolates browser concerns but does not yet add unit coverage around browser tree construction.

## Shipped Release

- Version: `0.1.21`
- Feature slug: `browser-view-model-extraction`
