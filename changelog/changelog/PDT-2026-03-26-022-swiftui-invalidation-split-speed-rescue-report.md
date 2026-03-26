# PDT-2026-03-26-022 SwiftUI Invalidation Split Speed Rescue Report

- Item ID: `PDT-2026-03-26-022`
- Title: `SwiftUI invalidation split speed rescue`
- Shipped release version: `0.1.60`
- Shipped feature slug: `swiftui-invalidation-split-speed-rescue`

## Summary Of What Changed

- Split the live UI shell onto narrower observable state slices for sidebar, review, navigation, inspector, compare, and presentation state so the main window no longer observes the whole `AppState`.
- Added cached review-content generations so context items, filtered visible items, and review-interaction items are reused across focus-only moves instead of being rebuilt on every body pass.
- Reworked review, grouped review, compare, and inspector views to render from review snapshots and compare snapshots instead of reading the full coordinator object directly.
- Replaced global thumbnail-driven `AppState.objectWillChange` invalidation with per-item thumbnail slots, so thumbnail decode completion updates only the relevant card or inspector preview.
- Added debug latency logging hooks for review arrows, review scroll, sidebar toggles, inspector toggles, review mode switches, compare open/close, and grouped-review escape transitions.
- Added regression coverage proving focus-only review moves do not refresh the sidebar snapshot and that triage updates do not rebuild the browser tree.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- Real-world latency still needs user validation on a large session before this rescue can be called sufficient.
- The existing grouped-review escape path is still an acknowledged follow-up outside this slice.
- If `0.1.60` still misses the speed target, the next approved follow-up should continue with a more aggressive review-surface path rather than reverting to smaller hotfixes.
