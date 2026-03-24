# PDT-2026-03-23-001 Release Versioning And UI Verification Report

## Summary

Implemented a visible release/version workflow and shipped the first two visibly verifiable UI cleanup items.

## Shipped Release

- Release version: `0.1.1`
- Feature slug: `release-versioning-ui`

## What Changed

- Added `APP_RELEASE.env` as the release source of truth for version, build, and latest feature slug.
- Updated the packaged app bundle build script to inject release metadata into the `.app` Info.plist.
- Added runtime release metadata loading in the app and displayed the current release marker in the bottom-left footer.
- Kept the review pane free of the old whole-pane blue focus ring.
- Strengthened card-level selection visibility so selected cards read clearly across the whole card without orange focus styling.
- Hardened the tracking instructions so implemented work now requires a release/version bump.

## Files Changed

- `APP_RELEASE.env`
- `AGENTS.md`
- `agents.md`
- `changelog/AGENTS.md`
- `changelog/backlog/PDT-2026-03-23-001-release-versioning-and-ui-verification.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/changelog/PDT-2026-03-23-001-release-versioning-and-ui-verification-report.md`
- `scripts/build_app_bundle.sh`
- `Sources/PhotoDiaryTriage/AppRelease.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`

## Verification

- `swift build` passed.
- Rebuilt the packaged app bundle.
- Relaunched `dist/PhotoDiaryTriage.app`.
- Confirmed the release metadata is now part of the app bundle build process.
- Fixed a packaging bug where the bundle `Info.plist` had literal `${APP_VERSION}` placeholders because the heredoc in `build_app_bundle.sh` was quoted.
- Verified the generated bundle now contains `CFBundleShortVersionString = 0.1.1`, `CFBundleVersion = 2`, and `PDTLatestFeatureSlug = release-versioning-ui`.

## Known Gaps

- `swift test` was not run here because this machine still reports `XCTest not available`.
- The subagent tool failed with an OS-level error in this session, so this item was completed locally rather than in delegated workers.
