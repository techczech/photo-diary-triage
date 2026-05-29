---
item_id: PDT-2026-05-29-087
title: Computer Use accessibility state
status: awaiting_user_review
target_release_version: 0.2.42
target_build: 119
target_feature_slug: computer-use-accessibility-state
created: 2026-05-29T09:36:50Z
---

## User Request Summary

- Run Computer Use ask protocol for `PhotoDiaryTriage`.
- Allow user to click `Always allow`.
- Do not guess about permissions.
- Keep spec/task first, then work, then close.

## Evidence

- `mcp__computer_use__.get_app_state` works for Finder.
- `mcp__computer_use__.get_app_state` on `/Applications/PhotoDiaryTriage.app` returns only `remoteConnection`.
- Follow-up `mcp__computer_use__.click` refuses because no active app state exists.
- Fresh `SkyComputerUseService` crash reports created during the `PhotoDiaryTriage` state calls.
- Unified log shows `AccessibilitySupport.UIElementError` from `SkyComputerUseService`.

## Constraints

- Preserve current crop interaction repair from `0.2.41`.
- Preserve archive browsing and photo log workflows.
- Do not type or click destructive UI just to force permissions.
- Use installed `/Applications/PhotoDiaryTriage.app` for final Computer Use verification.
- Keep change scoped to app accessibility/inspectability unless diagnosis proves otherwise.

## Implementation Intent

- Inspect SwiftUI accessibility modifiers and high-volume UI surfaces.
- Identify likely app-specific accessibility structure that trips Computer Use state extraction.
- Simplify or stabilize the offending accessibility exposure.
- Keep user-visible controls and keyboard triage behavior intact.
- Bump release to `0.2.42` / build `119`.

## Test Conditions

- `swift build` passes.
- `swift test` attempted; record environment blocker if XCTest remains unavailable.
- App bundle builds and installs.
- `mcp__computer_use__.get_app_state` for `/Applications/PhotoDiaryTriage.app` returns screenshot/accessibility tree, not `remoteConnection`.
- No fresh `SkyComputerUseService` crash appears during final app-state verification.

## Success Criteria

- User can trigger Computer Use app-state flow for `PhotoDiaryTriage`.
- If Codex asks for app permission, user can choose `Always allow`.
- Computer Use can inspect `PhotoDiaryTriage` enough for future crop verification.
- Changelog report and JSONL status close this item.

## Implementation Notes

- Confirmed Computer Use itself works by getting a full Finder state tree.
- Isolated `PhotoDiaryTriage` failure to inspector-open state.
- First failure source:
  - inspector `LazyVGrid` surfaces exposed as `AXOpaqueProviderGrid`.
- Remaining failure source:
  - inspector `GroupBox` labels exposed as large `AXServesAsTitleForUIElements` heading relationships.
- Replaced inspector-only `LazyVGrid` layouts with stack layouts.
- Replaced inspector `GroupBox` wrappers with plain `InspectorSectionPanel` cards.
- Installed `/Applications/PhotoDiaryTriage.app` as `APP_VERSION=0.2.42`, `APP_BUILD=119`, `APP_FEATURE_SLUG=computer-use-accessibility-state`.

## Verification

- `swift build` passed.
- `swift test` remains blocked by local Command Line Tools XCTest path issue:
  - `xcrun --sdk macosx --show-sdk-platform-path` cannot resolve `PlatformPath`.
  - SwiftPM exits with `error: XCTest not available`.
- `./scripts/build_app_bundle.sh` passed.
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app` passed.
- Installed bundle metadata:
  - `CFBundleShortVersionString=0.2.42`
  - `CFBundleVersion=119`
  - `PDTLatestFeatureSlug=computer-use-accessibility-state`
- Raw AX inspection with inspector open showed:
  - no `AXOpaqueProviderGroup` nodes;
  - no large inspector heading title arrays.
- `mcp__computer_use__.get_app_state` on `/Applications/PhotoDiaryTriage.app` returned a full state tree and screenshot with inspector visible.
- Crash report list did not advance after the successful Computer Use state call.

## User Review Focus

- Test `APP_VERSION=0.2.42`.
- Keep the inspector open.
- Ask Codex to use Computer Use on `PhotoDiaryTriage`.
- If an approval prompt appears, click `Always allow`.
- Confirm future crop checks can see the app instead of returning `remoteConnection`.
