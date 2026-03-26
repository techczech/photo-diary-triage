# PDT-2026-03-26-025 Compact Review And Compare Action Row Report

- Item ID: `PDT-2026-03-26-025`
- Title: `Compact review and compare action row`
- Shipped release version: `0.1.63`
- Shipped feature slug: `compact-review-and-compare-action-row`

## Summary Of What Changed

- Moved the compact S / X / D / R triage controls into the same metadata row as the file label and capture time on review cards.
- Replaced the wider RAW switch with a compact `R` control in both review cards and compare cards.
- Kept the `RAW` state visible inside the metadata pill summary so the active RAW selection state still reads clearly without adding a second row.
- Applied the same compact inline control pattern to compare cards so compare uses less vertical space as well.
- Preserved the existing keyboard shortcuts and the existing include/exclude/raw semantics.

## Files Changed

- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `APP_RELEASE.env`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/backlog/PDT-2026-03-26-025-compact-review-and-compare-action-row.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- The layout is intentionally compact, but the broader speed work can still be revisited later if the user wants more polish.
- If the user wants the compare or review cards to be even denser, a future slice could compress the remaining non-triage actions as well.
