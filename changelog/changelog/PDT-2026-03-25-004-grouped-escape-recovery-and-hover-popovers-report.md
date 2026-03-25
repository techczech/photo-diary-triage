# PDT-2026-03-25-004 Grouped Escape Recovery And Hover Popovers Report

## Summary Of What Changed

- Hardened grouped Escape recovery so leaving a scoped grouped-section review now routes back through the normal grouped-review state transition before restoring section focus.
- Added a regression assertion that grouped Escape returns to the full grouped review set rather than leaving the review area empty.
- Replaced the fragile in-layout hover chips with hover popovers so shortcut hints are not clipped by local layout bounds.
- Preserved the compact shortcut-only content inside the hover hint itself.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-25-004-grouped-escape-recovery-and-hover-popovers.md`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- Hover popovers now use a more reliable presentation path, but they still depend on standard pointer hover behavior, so they are not available from keyboard-only navigation.
- This slice fixes grouped Escape recovery and hover visibility; it does not yet add a persistent visible indicator that you are inside a scoped grouped-section review.

## Shipped Release

- Version: `0.1.43`
- Feature slug: `grouped-escape-recovery-and-hover-popovers`
