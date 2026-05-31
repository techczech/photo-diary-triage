# PDT-2026-05-31-109 global tooltip layer icon help report

---
item_id: PDT-2026-05-31-109
title: Global tooltip layer and icon button help
status: implemented
app_version: 0.2.63
app_build: 140
feature_slug: global-tooltip-layer-icon-help
completed_at: 2026-05-31T16:55:23Z
---

## Summary

Tooltips now use one root-level SwiftUI layer for review-grid shortcut chips, so they render above the gallery instead of being clipped by card or toolbar layout. The tooltip bubble is wider, uses larger wrapped text, and is positioned away from the hovered control.

Icon-only window toolbar controls now get durable native AppKit tooltip and accessibility Help through a narrow bridge. This covers app-owned controls and the automatic left-sidebar toggle.

## User-Visible Behaviour

- Hovering S/C/X/R chips shows one large tooltip above the gallery content.
- The tooltip does not cover the chip it describes.
- Source, Settings, Open, Compare, Inspector, Shortcuts, and the left-sidebar toggle expose Help.
- The right inspector close button and review toolbar buttons still expose Help.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-31-109-global-tooltip-layer-icon-help.md`
- `changelog/backlog.jsonl`

## Verification

- Passed: `swift test --filter reviewGridTooltipSourceKeepsParentSelectionHelpOffCardControls`
- Passed: `swift test --filter mainToolbarDoesNotInstallDuplicateSidebarButton`
- Passed: `swift test --filter ReviewInteractionTests` with 88 tests.
- Built: `./scripts/build_app_bundle.sh`
- Verified bundle metadata:
  - `CFBundleShortVersionString=0.2.63`
  - `CFBundleVersion=140`
  - `PDTLatestFeatureSlug=global-tooltip-layer-icon-help`
- Verified with Computer Use:
  - The rebuilt app showed `v0.2.63 · global-tooltip-layer-icon-help`.
  - The left-sidebar toggle exposed `Help: Hide sidebar`.
  - Source, Settings, Open, Compare, Inspector, Shortcuts, and More exposed Help.
  - Review toolbar controls and S/C/X/R chips exposed Help.
  - A live hover over the first S chip showed one tooltip above the gallery content, offset from the chip.

## Handoff

Test `0.2.63` build `140`. In Camera Triage, hover S/C/X/R chips and icon-only toolbar buttons; each should show one clear tooltip, not a clipped or stacked pair.
