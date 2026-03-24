# PDT-2026-03-24-026 Review Interaction Rescue Report

## Summary Of What Changed

- Reworked the review grid interaction path so mouse clicks carry real modifier flags and double-clicks open preview from the focused item instead of relying on global `NSEvent.modifierFlags`.
- Replaced guessed screen-width navigation with measured review-grid metrics plus persistent card sizing, toolbar controls, settings persistence, explicit spacing, and a subtle base border on review cards.
- Fixed review-key focus handling so the hidden key responder no longer steals focus back from other controls, added grid-size keyboard controls (`+`, `-`, `0`), and changed `Escape` to exit grid focus instead of silently clearing selection.
- Upgraded preview and compare into usable decision tools: preview now supports previous/next browsing, compare can be launched from burst/cluster inline sections, and compare cards support direct select/mark/RAW/preview actions without leaving the sheet.
- Added a bounded thumbnail scheduler that prioritizes visible items before background work and avoids duplicate thumbnail requests.
- Added regression coverage for click-context translation, measured grid metrics, compare request building, preview navigation, double-click preview opening, and thumbnail scheduling.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInlineViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/Models.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Sources/PhotoDiaryTriage/ThumbnailScheduler.swift`
- `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/TestSupport.swift`
- `Tests/PhotoDiaryTriageTests/ThumbnailSchedulerTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-026-review-interaction-rescue.md`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- `open dist/PhotoDiaryTriage.app`

## Manual Verification Checklist Status

- Grid cards no longer use the old overlapping adaptive width heuristic; card width, spacing, and base borders are now explicit in code.
- Mouse selection modifier handling, keyboard focus gating, preview navigation, compare actions, and thumbnail scheduling are covered by automated regression tests.
- Full hands-on usability verification for Shift-click, Command-click, review-grid browsing, and compare-mode decision flow still needs user validation in the launched app.

## Known Gaps Or Follow-Up Items

- Archive tree caching and faster import concurrency are still pending follow-on work from the broader rescue plan.
- Real-world responsiveness on very large sessions still needs user validation against the new thumbnail scheduler.
- The compare workflow now supports direct decisions, but additional burst/cluster entry points outside the inline sections may still be worth adding after user testing.

## Shipped Release

- Version: `0.1.28`
- Feature slug: `review-interaction-rescue`
