# PDT-2026-05-23-068: compare action hard scope

## Summary

- Compare mode now clamps current selection scope in `AppState`, not only in the compare view.
- Generic menu/command actions for S/C/X/D route to compare-specific actions while compare is open.
- Select all, deselect, clear, space toggle, command-click, shift-click, and RAW toggle all ignore stale outside-compare IDs while compare is open.
- Exclude from a compare-wide selection removes only compare items and leaves outside included photos unchanged.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-23-068-compare-action-hard-scope.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test --filter compare`
  - passed: 18 tests
  - includes stale whole-folder selection regressions while compare is open
- `swift test`
  - passed: 124 tests
- `./scripts/build_app_bundle.sh`
  - built `dist/PhotoDiaryTriage.app`
- `open dist/PhotoDiaryTriage.app`
  - launched app process successfully

## Known Gaps Or Follow-Up Items

- Manual confirmation still needed with real photos:
  - open compare from a small set
  - press Cmd-A
  - exclude
  - confirm only compare images changed and previous included photos outside compare stayed included

## Shipped Release

- APP_VERSION: 0.2.28
- APP_BUILD: 105
- APP_FEATURE_SLUG: compare-action-hard-scope
