# PDT-2026-05-31-107 remove duplicate sidebar toolbar button report

---
item_id: PDT-2026-05-31-107
title: Remove duplicate sidebar toolbar button
status: implemented
shipped_version: 0.2.61
shipped_build: 138
shipped_feature_slug: remove-duplicate-sidebar-toolbar-button
---

## Summary

Removed the custom `Sidebar` toolbar button from `ContentView.mainToolbar` so the left sidebar control no longer appears in the right-side toolbar cluster near the inspector. The native left titlebar/sidebar control remains available, and the inspector toolbar button remains unchanged.

## Files Changed

- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-31-107-remove-duplicate-sidebar-toolbar-button.md`

## Verification Performed

- Ran `swift test --filter mainToolbarDoesNotInstallDuplicateSidebarButton`.
- Ran `swift test --filter appChromeKeyboardShortcutsRequireCommandOption`.
- Ran `./scripts/build_app_bundle.sh`.
- Verified bundle metadata:
  - `CFBundleShortVersionString`: `0.2.61`
  - `CFBundleVersion`: `138`
  - `PDTLatestFeatureSlug`: `remove-duplicate-sidebar-toolbar-button`
- Used Computer Use on the rebuilt app. The toolbar showed the native `Hide Sidebar` control, then Workspace, Source, Settings, Open, Compare, Inspector, and Shortcuts. The custom `Sidebar` button was no longer present in the right-side toolbar group.

## Known Gaps

- None known.

## Release

Shipped as `0.2.61` build `138` with feature slug `remove-duplicate-sidebar-toolbar-button`.
