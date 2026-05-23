# PDT-2026-05-23-067: scoped preview and compare selection

## Summary

- Compare view Cmd-A now selects only the images currently in compare.
- Compare view Cmd-Shift-A clears compare selection without treating the whole folder as the active scope.
- Full image view now exposes S, C, X, D, and RAW controls where the item is editable.
- Full image view keyboard handling now accepts S/C/X/D/R for the previewed photo.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-23-067-scoped-preview-compare-selection.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test --filter ReviewInteractionTests`
  - passed: 64 tests
- `swift test`
  - passed: 119 tests
- `./scripts/build_app_bundle.sh`
  - built `dist/PhotoDiaryTriage.app`
- `open dist/PhotoDiaryTriage.app`
  - launched app process successfully

## Known Gaps Or Follow-Up Items

- Manual UI confirmation still needed on real photos:
  - compare view Cmd-A / Cmd-Shift-A
  - full image view S/C/X/D/R buttons and keys

## Shipped Release

- APP_VERSION: 0.2.27
- APP_BUILD: 104
- APP_FEATURE_SLUG: scoped-preview-compare-selection
