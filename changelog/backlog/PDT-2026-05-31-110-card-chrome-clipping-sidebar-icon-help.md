# PDT-2026-05-31-110 card chrome clipping sidebar icon help

---
item_id: PDT-2026-05-31-110
title: Card chrome clipping and sidebar icon help
status: awaiting_user_review
target_version: 0.2.64
target_build: 141
target_feature_slug: card-chrome-clipping-sidebar-icon-help
---

## User Request Summary

Gallery cards still have visual chrome problems: the blue selected outline overlaps neighbouring card content, the copied pill can appear twice or clipped at card edges, and some icon-only buttons at the top of the sidebar do not show tooltips.

## Constraints

- Keep the visual focus on photos.
- Selection chrome must not bleed into neighbouring cards.
- Copied/imported status should have one clear visible representation per item.
- Tooltip/help coverage must include icon-only sidebar or inspector controls.
- Verify the rebuilt app with Computer Use before reporting completion.

## Implementation Intent

1. Inspect review card badge and selection overlay composition.
2. Move selection chrome inside the card bounds or clip it safely.
3. Remove duplicate copied/imported pill rendering for the same card state.
4. Add durable help for sidebar/inspector icon-only controls that are outside the main toolbar bridge.
5. Add regression tests for card chrome and icon help.
6. Build, launch, and inspect the app with Computer Use.

## Test Conditions

- Focused review/card chrome tests pass.
- Review interaction tests pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.64` build `141`.
- Computer Use verifies icon-only sidebar/inspector controls expose Help and gallery cards no longer show the clipped duplicate copied pill.

## Success Criteria

- A selected card outline stays inside its own card.
- Copied/imported status appears once per card and is not clipped at the inter-card boundary.
- Icon-only controls at the top of the sidebar/inspector expose Help.
- Camera Triage screenshot inspection confirms the repaired layout.

## Current Status

Implemented in `0.2.64` build `141`, awaiting user review.

## Verification Evidence

- `swift test --filter mainToolbarDoesNotInstallDuplicateSidebarButton`
- `swift test --filter ReviewInteractionTests` with 89 tests
- `./scripts/build_app_bundle.sh`
- Bundle metadata: `CFBundleShortVersionString=0.2.64`, `CFBundleVersion=141`, `PDTLatestFeatureSlug=card-chrome-clipping-sidebar-icon-help`
- Computer Use verified the rebuilt app reports `v0.2.64 · card-chrome-clipping-sidebar-icon-help`.
- Computer Use verified the 2026 / 05 - May Camera Triage grid: selected blue outline stays inside the card, Copied appears once per copied card, and neighbouring cards are not overlapped.
- Computer Use verified Help text on the icon-only top toolbar controls: Source, Settings, Open, Compare, Inspector, Shortcuts, More, and the left sidebar toggle.
