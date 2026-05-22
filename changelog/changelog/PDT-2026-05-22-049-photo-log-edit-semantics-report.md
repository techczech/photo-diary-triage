# PDT-2026-05-22-049 Photo Log Edit Semantics Report

## Summary

- Renamed the photo-log membership and S/C/X action from `Edit Items` to `Edit Log`.
- Renamed metadata-only editing to `Details` / `Log Details`.
- Updated hover help, sheet titles, sheet subtitles, workflow guidance, and status messages so:
  - `Edit Log` means add/remove photos and change S/C/X status.
  - `Details` means title, notes, date range, and scope only.
- Updated imported/source-cleaned lock messages to say `Edit Log` is locked.
- Bumped release metadata to `APP_VERSION=0.2.10`, `APP_BUILD=87`, `APP_FEATURE_SLUG=photo-log-edit-semantics`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/PhotoLogStatusPolicy.swift`
- `Sources/PhotoDiaryTriage/WorkflowGuidanceResolver.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `changelog/backlog/PDT-2026-05-22-049-photo-log-edit-semantics.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift test`
  - Passed: 100 tests.
- `scripts/build_app_bundle.sh`
  - Built `dist/PhotoDiaryTriage.app`.
- `open -n dist/PhotoDiaryTriage.app`
  - Launched the rebuilt app.
- Bundle metadata check:
  - `CFBundleShortVersionString`: `0.2.10`
  - `CFBundleVersion`: `87`
  - `PDTLatestFeatureSlug`: `photo-log-edit-semantics`

## Known Gaps Or Follow-Up Items

- No automated screenshot assertion for the button labels.
- This changes wording only; selection and membership-edit behavior are unchanged.

## Shipped Release

- Shipped APP_VERSION: `0.2.10`
- Shipped APP_BUILD: `87`
- Shipped feature slug: `photo-log-edit-semantics`
