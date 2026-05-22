# PDT-2026-05-22-048 Workflow State Guidance Report

## Summary

- Added a live workflow guidance snapshot with `State`, `Now`, and `Next` lines.
- Shows the guidance in the sidebar status area, the footer status bar, and a new inspector `Workflow` section.
- Added state-specific guidance for:
  - no source open
  - source loading, empty, or failed
  - source inbox triage
  - source inbox ready to create a photo log
  - photo log in progress with no uncopied `S` photos
  - photo log ready to copy
  - copy in progress
  - copy failed
  - copied files waiting for backup confirmation
  - source cleanup readiness
  - archive browsing as read-only
- Kept selection behavior unchanged.
- Bumped release metadata to `APP_VERSION=0.2.9`, `APP_BUILD=86`, `APP_FEATURE_SLUG=workflow-state-guidance`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Sources/PhotoDiaryTriage/WorkflowGuidanceResolver.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `changelog/backlog/PDT-2026-05-22-048-workflow-state-guidance.md`
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
  - `CFBundleShortVersionString`: `0.2.9`
  - `CFBundleVersion`: `86`
  - `PDTLatestFeatureSlug`: `workflow-state-guidance`

## Known Gaps Or Follow-Up Items

- No automated screenshot assertion for the new sidebar/inspector layout.
- RAW companion workflow remains unchanged.

## Shipped Release

- Shipped APP_VERSION: `0.2.9`
- Shipped APP_BUILD: `86`
- Shipped feature slug: `workflow-state-guidance`
