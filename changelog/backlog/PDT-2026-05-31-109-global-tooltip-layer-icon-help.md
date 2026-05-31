# PDT-2026-05-31-109 global tooltip layer icon help

---
item_id: PDT-2026-05-31-109
title: Global tooltip layer and icon button help
status: awaiting_user_review
target_version: 0.2.63
target_build: 140
target_feature_slug: global-tooltip-layer-icon-help
---

## User Request Summary

Tooltips still render under other UI or cover the element they belong to. Some icon-only buttons, especially in the sidebar/toolbar area, do not expose tooltips. Every button without a text label should have a tooltip, and the result must be checked with Computer Use.

## Constraints

- Move custom shortcut tooltips above the app content so they cannot be clipped by local card or toolbar layout.
- Position custom tooltips beside, above, or below the source control so they do not cover the control itself.
- Keep tooltip text larger and wrapped.
- Ensure app-owned icon-only toolbar buttons expose Help/accessibility tooltip text.
- Preserve native sidebar and inspector behaviour.
- Verify the rebuilt app with Computer Use before reporting completion.

## Implementation Intent

1. Replace local shortcut tooltip overlays with a single root-level floating tooltip layer.
2. Publish hovered control frames from `shortcutHint` into that layer.
3. Clamp tooltip placement inside the root view and avoid the source control bounds.
4. Add explicit accessibility help to icon-only app toolbar controls.
5. Add regression tests for the global layer and toolbar help.
6. Build, launch, and inspect the app with Computer Use.

## Test Conditions

- Tooltip regression tests pass.
- Review interaction tests pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.63` build `140`.
- Computer Use verifies icon-only toolbar controls expose Help where app code owns them.

## Success Criteria

- Shortcut tooltips appear from one root layer above the content.
- The tooltip no longer covers the S/C/X/R chip it describes.
- Icon-only toolbar buttons such as Source, Settings, Open, Compare, Inspector, and Shortcuts expose Help text in Computer Use.

## Current Status

Implemented in `0.2.63` build `140`, awaiting user review.

## Verification Evidence

- `swift test --filter reviewGridTooltipSourceKeepsParentSelectionHelpOffCardControls`
- `swift test --filter mainToolbarDoesNotInstallDuplicateSidebarButton`
- `swift test --filter ReviewInteractionTests` with 88 tests
- `./scripts/build_app_bundle.sh`
- Bundle metadata: `CFBundleShortVersionString=0.2.63`, `CFBundleVersion=140`, `PDTLatestFeatureSlug=global-tooltip-layer-icon-help`
- Computer Use verified the rebuilt app reports `v0.2.63 · global-tooltip-layer-icon-help`.
- Computer Use verified Help on the left sidebar toggle, Source, Settings, Open, Compare, Inspector, Shortcuts, review toolbar controls, and S/C/X/R chips.
- Computer Use hover screenshot verified one large tooltip renders above the gallery content and does not cover the source chip.
