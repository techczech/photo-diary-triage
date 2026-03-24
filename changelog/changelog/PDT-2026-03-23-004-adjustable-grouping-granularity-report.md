# PDT-2026-03-23-004 Adjustable Grouping Granularity Report

## Summary Of What Changed

- Added visible grouping controls in Settings for burst grouping and time-cluster grouping.
- Reused the existing threshold settings instead of introducing a separate preset model.
- Changing either threshold now persists immediately and regroups the active session without re-scanning the SSD.
- Regrouping preserves media-item identity, refreshes the browser state, and keeps the current sidebar node when it still exists.
- Fixed grouping recomputation so stale burst/time-cluster IDs are cleared before new groups are assigned.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/GroupingService.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift`
- `changelog/backlog/PDT-2026-03-23-004-adjustable-grouping-granularity.md`

## Verification Performed

- `swift build`
- added deterministic grouping tests for threshold changes and stale-group cleanup
- manual code-path verification of immediate regrouping and settings persistence wiring

## Known Gaps Or Follow-Up Items

- `swift test` still cannot run in this environment because local macOS Command Line Tools report `XCTest not available`.
- This feature still needs user review in the running app to confirm the grouping changes feel right on real photo sets.

## Shipped Release

- Version: `0.1.7`
- Feature slug: `grouping-granularity`
