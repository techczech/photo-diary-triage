# PDT-2026-03-25-005 Escape Scroll Recovery And Stable Shortcut Badges Report

## Summary Of What Changed

- Changed grouped-section focus restoration so it always reissues a fresh scroll-to-section request, even when returning to the same section ID after drill-in.
- Removed the crash-prone hover popover hint system and replaced it with stable always-visible shortcut badges on the key controls.
- Kept full shortcut descriptions in the help text while making the on-screen discoverability layer layout-safe.
- Updated the grouped-section navigation test to match the new asynchronous scroll-request behavior.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-25-005-escape-scroll-recovery-and-stable-shortcut-badges.md`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- The shortcut badges are stable and always visible, but they are a different UX from hover-only hints.
- If grouped Escape still feels wrong in real use after this scroll reset, the next step is to record the exact section hierarchy and selected node that reproduces it so the restore path can be made context-specific.

## Shipped Release

- Version: `0.1.44`
- Feature slug: `escape-scroll-recovery-and-stable-shortcut-badges`
