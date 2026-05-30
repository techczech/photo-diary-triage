# PDT-2026-05-31-101 date label navigation

---
item_id: PDT-2026-05-31-101
title: Date label navigation
status: awaiting_user_review
target_version: 0.2.56
target_build: 133
target_feature_slug: date-label-navigation
---

## User Request Summary

The archive/source tree date labels are too terse. Month rows should show labels like `05 - May`, and day rows should show labels like `07 - Fri` or `08 - Wed` so keyboard and visual navigation is easier.

## Constraints

- Preserve existing tree structure, selection, expansion, and archive browsing behaviour.
- Keep labels compact enough for the sidebar.
- Do not change folder names on disk.
- Keep archive and live source navigation consistent where possible.
- Preserve fast archive tree building.

## Implementation Intent

1. Add shared month/day label formatting for `BrowserNode` titles.
2. Use `MM - Month` for month nodes.
3. Use `DD - EEE` for day nodes when the full year/month/day is known.
4. Keep archive walk folder names untouched except for existing folder titles.
5. Add focused regression coverage for session date nodes and archive month nodes.

## Test Conditions

- Session fixture with known captured dates verifies month and weekday labels.
- Archive fixture with numbered month folders verifies month label enrichment.
- Existing navigation tests continue to pass.
- App bundle builds successfully.

## Success Criteria

- Month rows show `05 - May` instead of only `05` where the month is known.
- Day rows show a zero-padded day plus weekday abbreviation.
- Archive month folders such as `05` display as `05 - May` without renaming folders.
- The implementation is covered by focused tests and release metadata.

## Current Status

Implemented pending user review in `0.2.56` build `133`.
