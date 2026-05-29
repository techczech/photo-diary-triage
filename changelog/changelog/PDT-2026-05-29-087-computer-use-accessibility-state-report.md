# PDT-2026-05-29-087 Computer Use accessibility state report

item_id: PDT-2026-05-29-087
status: implemented
shipped_release_version: 0.2.42
shipped_feature_slug: computer-use-accessibility-state

## Summary

Fixed the `PhotoDiaryTriage` inspector accessibility structure that crashed `SkyComputerUseService`.
The installed app is now `APP_VERSION=0.2.42`, build `119`, and Computer Use can retrieve the app state with the inspector open.

## User-Visible Behavior

- Inspector stays visible and usable.
- Inspector metric badges and action buttons are arranged in stable stack layouts.
- Inspector sections still read as separate panels but no longer use SwiftUI `GroupBox`.
- Computer Use can inspect the app instead of returning only `remoteConnection`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorWorkflowViews.swift`
- `changelog/backlog/PDT-2026-05-29-087-computer-use-accessibility-state.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build` passed.
- `swift test` attempted and blocked by the local XCTest/toolchain issue.
- `git diff --check` passed.
- `./scripts/build_app_bundle.sh` passed.
- Installed `/Applications/PhotoDiaryTriage.app`.
- Installed bundle metadata:
  - `CFBundleShortVersionString=0.2.42`
  - `CFBundleVersion=119`
  - `PDTLatestFeatureSlug=computer-use-accessibility-state`
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app` passed.
- Raw AX inspection with inspector open showed no `AXOpaqueProviderGroup` nodes and no large inspector heading title arrays.
- `mcp__computer_use__.get_app_state` on `/Applications/PhotoDiaryTriage.app` returned the full accessibility tree and screenshot with inspector visible.
- Crash reports did not advance after the successful state call.

## Known Gaps

- Automated tests are still blocked by local Command Line Tools:
  - `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`.
  - SwiftPM reports `error: XCTest not available`.
- The permission approval dialog did not appear during final verification, likely because current Computer Use permission was already sufficient after the app became inspectable.
