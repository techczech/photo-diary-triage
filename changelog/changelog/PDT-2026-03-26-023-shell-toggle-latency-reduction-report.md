# PDT-2026-03-26-023 Shell Toggle Latency Reduction Report

- Item ID: `PDT-2026-03-26-023`
- Title: `Shell toggle latency reduction`
- Shipped release version: `0.1.61`
- Shipped feature slug: `shell-toggle-latency-reduction`

## Summary Of What Changed

- Replaced the app shell `NavigationSplitView` with an app-managed `HStack` shell so left-sidebar visibility no longer depends on the system split-view sidebar controller.
- Moved sidebar visibility to explicit app state and wired keyboard focus so reopening the sidebar restores the sidebar responder only when the sidebar is still active.
- Short-circuited hidden inspector updates by publishing a lightweight hidden inspector snapshot and rendering `Color.clear` while the inspector is closed.
- Tightened the right inspector shell so hiding and reopening it no longer drives the full heavy inspector content through every focus change.
- Removed the system `SidebarCommands()` path so the app’s keyboard command now matches the app-managed sidebar visibility behavior.
- Added regression coverage proving sidebar visibility is app-managed and that hidden inspectors do not refresh while focus moves through review items.
- Hardened the sidebar responder handoff to avoid async window teardown crashes during tests and edge-case UI timing.

## Files Changed

- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- Arrow-key navigation is improved but still needs user validation against a real large session.
- The grouped-review escape path remains a separate known usability follow-up outside this performance slice.
- If sidebar and inspector toggles still miss the target on `0.1.61`, the next follow-up should profile the remaining shell work instead of expanding feature scope.
