# PDT-2026-05-23-062: Start New Photo Log Primary Action Report

## Summary

- Added a prominent `Start New Photo Log` action to the photo-log copy/action strip.
- The action closes the current photo log by reopening the matching source inbox, using the saved inbox immediately when available.
- Reset stale copy-operation state when moving back to the source inbox so the next workflow does not still show the previous copy result.
- Added the same action to the Triage menu.
- Updated copied-log workflow guidance to point to `Start New Photo Log` while preserving archive review, backup confirmation, and cleanup guidance.
- Bumped release metadata to `APP_VERSION=0.2.23`, `APP_BUILD=100`, `APP_FEATURE_SLUG=start-new-photo-log-primary-action`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppCommands.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/WorkflowGuidanceResolver.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `changelog/backlog/PDT-2026-05-23-062-start-new-photo-log-primary-action.md`

## Verification Performed

- `swift test --filter sourceInboxCanAddMarkedPhotosToExistingCopiedLog`
  - Targeted regression passed.
- `swift test`
  - 112 tests passed.
- `./scripts/build_app_bundle.sh`
  - Built `dist/PhotoDiaryTriage.app`.
- `open -n dist/PhotoDiaryTriage.app && sleep 2 && pgrep -fl PhotoDiaryTriage`
  - Confirmed the packaged app launched from `dist/PhotoDiaryTriage.app`.
- `PlistBuddy` release metadata checks
  - `CFBundleShortVersionString=0.2.23`
  - `CFBundleVersion=100`
  - `PDTLatestFeatureSlug=start-new-photo-log-primary-action`

## Known Gaps Or Follow-Up Items

- Live visual confirmation with a real copied photo log is still needed to judge exact button placement and whether the label should stay `Start New Photo Log` or become even more explicit.

## Shipped Release

- shipped version: `0.2.23`
- shipped build: `100`
- shipped feature slug: `start-new-photo-log-primary-action`
