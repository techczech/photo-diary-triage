# PDT-2026-05-31-108 single large wrapped tooltips report

---
item_id: PDT-2026-05-31-108
title: Single large wrapped tooltips
status: implemented
shipped_version: 0.2.62
shipped_build: 139
shipped_feature_slug: single-large-wrapped-tooltips
---

## Summary

Changed shortcut-hinted controls to use one visible tooltip system. `ShortcutHintModifier` no longer installs native SwiftUI `.help`, so it does not show the macOS tooltip underneath the custom hover bubble. The custom bubble now uses larger callout text and a fixed wrapped width.

Removed extra native `.help` modifiers from shortcut-hinted controls that could still create the same double-tooltip pattern.

## Files Changed

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-31-108-single-large-wrapped-tooltips.md`

## Verification Performed

- Ran `swift test --filter reviewGridTooltipSourceKeepsParentSelectionHelpOffCardControls`.
- Ran `swift test --filter ReviewInteractionTests`; all 88 Swift Testing tests passed.
- Checked source for `.help(...)` immediately adjacent to `.shortcutHint(...)`; no matches remained.
- Ran `./scripts/build_app_bundle.sh`.
- Verified bundle metadata:
  - `CFBundleShortVersionString`: `0.2.62`
  - `CFBundleVersion`: `139`
  - `PDTLatestFeatureSlug`: `single-large-wrapped-tooltips`
- Used Computer Use on the rebuilt app. The app reported `v0.2.62 · single-large-wrapped-tooltips`, Camera Triage opened, and S/C/X/R controls remained present with action-specific accessibility text.

## Known Gaps

- Computer Use does not have a hover-only action, so the duplicate visible tooltip behavior is guarded by source tests: shortcut-hinted controls no longer install SwiftUI `.help`, and the custom bubble is now the only visible tooltip path for those controls.

## Release

Shipped as `0.2.62` build `139` with feature slug `single-large-wrapped-tooltips`.
