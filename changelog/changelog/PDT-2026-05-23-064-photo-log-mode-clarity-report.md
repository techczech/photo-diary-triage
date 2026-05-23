# PDT-2026-05-23-064: Photo log mode clarity report

## Summary

- Made archive-on-disk matches real copied state in the loaded source inbox instead of a display-only badge.
- Locked S/C/X and RAW changes for copied items, and kept copied/on-disk items out of new photo-log creation and copy plans.
- Changed copied tiles to show `Copied` as the primary status, with a visible lock note for archive-on-disk matches.
- Clarified the main header context so Camera Triage now distinguishes `Source Inbox Triage` from `Active Photo Log`.
- Added a cognitive walkthrough report for the revised source-inbox to photo-log copy flow.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/SessionMutationCoordinator.swift`
- `Sources/PhotoDiaryTriage/StateSupport.swift`
- `Sources/PhotoDiaryTriage/UIState.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `Tests/PhotoDiaryTriageTests/StateSupportTests.swift`
- `cognitive-walkthroughs/photo-log-mode-clarity-start-copy-flow/00-meta.md`
- `cognitive-walkthroughs/photo-log-mode-clarity-start-copy-flow/walkthrough.md`
- `changelog/backlog/PDT-2026-05-23-064-photo-log-mode-clarity.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift test` passed with 114 tests.
- `./scripts/build_app_bundle.sh`
- Launched `dist/PhotoDiaryTriage.app`
- Inspected app availability with Computer Use; the tool saw the running app but returned only `remoteConnection` for window state.

## Known Gaps Or Follow-Up Items

- Computer Use did not return a usable accessibility tree or screenshot in this run, so visual confirmation is limited to build launch plus code-level and test-level verification.
- The walkthrough is an agent inspection, not observed user testing.

## Release

- shipped release version: `0.2.25`
- shipped build: `102`
- shipped feature slug: `photo-log-mode-clarity`
