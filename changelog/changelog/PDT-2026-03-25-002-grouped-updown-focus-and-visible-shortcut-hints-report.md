# PDT-2026-03-25-002 Grouped Up-Down Focus And Visible Shortcut Hints Report

## Summary Of What Changed

- Fixed the review key responder so it reclaims first-responder status whenever the review surface is still focused, which keeps grouped-section keyboard navigation active after clicking a section header.
- Preserved the section-header left and right collapse behavior while making grouped-section up and down work through the same plain-arrow path after header focus.
- Replaced tooltip-only shortcut discoverability with visible hover hint bubbles on the main review controls, grouped review controls, compare controls, preview controls, and review-item actions.
- Kept macOS help text as a fallback while adding the visible in-app hint layer.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-25-002-grouped-updown-focus-and-visible-shortcut-hints.md`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- The visible hint layer currently targets the main triage surfaces and controls. If you want the same treatment in the sidebar tree and inspector metadata surfaces, that can be added in a follow-up slice.
- This slice relies on manual verification for the actual hover experience because the test suite does not cover UI hover presentation.

## Shipped Release

- Version: `0.1.41`
- Feature slug: `grouped-updown-focus-and-visible-shortcut-hints`
