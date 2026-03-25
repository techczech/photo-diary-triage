# PDT-2026-03-25-003 Grouped Enter Escape And Shortcut Chip Cleanup Report

## Summary Of What Changed

- Added grouped-section `Return` handling so a focused section header now enters that section for item navigation instead of behaving like photo preview open.
- Added grouped-section `Escape` handling so item navigation can climb back out to section-header focus, and `Cmd-Return` or `Ctrl-Return` now drills into the focused section as a scoped review set.
- Added scoped grouped-section review state so drilling into a grouped section behaves like opening a folder-level subset.
- Changed shortcut bubbles to show only the shortcut chord, while keeping the full descriptions in macOS help text and in the shortcuts sheet.
- Updated the shortcuts sheet copy so it matches the new grouped `Return`, `Escape`, and `Cmd-Return` behavior.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-25-003-grouped-enter-escape-and-shortcut-chip-cleanup.md`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- Scoped grouped-section drill-in currently returns to grouped selection with `Escape`, but there is not yet a dedicated visible breadcrumb or banner showing that you are inside a scoped section subset.
- Hover bubbles are now compact, shortcut-only chips; if you want always-visible shortcut badges on specific controls, that would be a separate UI choice.

## Shipped Release

- Version: `0.1.42`
- Feature slug: `grouped-enter-escape-and-shortcut-chip-cleanup`
