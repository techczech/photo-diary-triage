# PDT-2026-03-23-002 Default SSD Auto-Load Report

## Summary

Implemented automatic loading for the configured default SSD source on app launch and when the SSD volume is mounted while the app is already open.

## Shipped Release

- Release version: `0.1.2`
- Feature slug: `default-ssd-autoload`

## What Changed

- Added startup auto-load for the configured default SSD root.
- Added volume-mount monitoring through `NSWorkspace.didMountNotification`.
- Resolved the default review folder safely by preferring `DCIM` under the configured SSD root when present.
- Prevented mount-time auto-load from overriding an unrelated active session unexpectedly.
- Advanced the visible in-app release marker to the new shipped version and feature slug.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/PhotoDiaryTriageApp.swift`
- `changelog/backlog/PDT-2026-03-23-002-default-ssd-auto-load.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/changelog/PDT-2026-03-23-002-default-ssd-auto-load-report.md`

## Verification

- `swift build` passed.
- Rebuilt the packaged app bundle.
- Relaunched `dist/PhotoDiaryTriage.app`.
- Verified the bundle release marker now advertises `0.1.2` and `default-ssd-autoload`.
- Removed the mount-notification concurrency warning from the implementation.

## Known Gaps

- `swift test` was not run here because this machine still reports `XCTest not available`.
- The implementation currently prefers `DCIM` under the configured SSD root; if the source structure changes in the future, that resolution rule may need to become configurable.
