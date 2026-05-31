# PDT-2026-05-31-107 remove duplicate sidebar toolbar button

---
item_id: PDT-2026-05-31-107
title: Remove duplicate sidebar toolbar button
status: awaiting_user_review
target_version: 0.2.61
target_build: 138
target_feature_slug: remove-duplicate-sidebar-toolbar-button
---

## User Request Summary

The open/close left sidebar button is confusing when it appears in the right-side toolbar area near the inspector. It should only appear on the left sidebar side.

## Constraints

- Remove the duplicate left-sidebar toggle from the right-side toolbar area.
- Preserve the left-side/sidebar toggle path.
- Preserve the inspector toggle and keyboard/toolbar access for the inspector.
- Keep release tracking current.
- Verify the rebuilt macOS app with Computer Use before reporting completion.

## Implementation Intent

1. Inspect toolbar item placement in `ContentView`.
2. Remove the sidebar toggle toolbar item that lands next to the inspector/right-side controls.
3. Keep the inspector control and other toolbar actions unchanged.
4. Build the app and verify the toolbar with Computer Use.

## Test Conditions

- App builds successfully.
- Bundle metadata reports `0.2.61` build `138`.
- Computer Use verifies the toolbar no longer shows the duplicate `Sidebar` button in the right-side group.

## Success Criteria

- The confusing sidebar toggle no longer appears next to the inspector/right-side toolbar controls.
- Sidebar visibility remains controllable from the left/native sidebar control.
- The inspector toggle remains available.

## Current Status

Implemented pending user review in `0.2.61` build `138`.
