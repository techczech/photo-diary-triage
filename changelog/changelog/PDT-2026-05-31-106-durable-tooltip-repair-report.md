# PDT-2026-05-31-106 durable tooltip repair report

---
item_id: PDT-2026-05-31-106
title: Durable tooltip repair
status: implemented
shipped_version: 0.2.60
shipped_build: 137
shipped_feature_slug: durable-tooltip-repair
---

## Summary

Fixed the gallery tooltip regression by removing the generic selection help from the whole card and putting action-specific help on the actual interactive controls. The S/C/X/D/R controls now expose descriptive tooltips and accessibility Help instead of one-letter or inherited selection text.

## Files Changed

- `Sources/PhotoDiaryTriage/ReviewTooltipText.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-31-106-durable-tooltip-repair.md`

## Verification Performed

- Before fix, Computer Use on `0.2.59` showed gallery chip buttons with inherited generic Help: `Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview.`
- Ran `swift test --filter ReviewInteractionTests`; all 87 Swift Testing tests passed.
- Ran `swift test --filter reviewTooltip`; tooltip text regression test passed.
- Ran `swift test --filter reviewGridTooltip`; source guard regression test passed.
- Ran `./scripts/build_app_bundle.sh`.
- Verified bundle metadata:
  - `CFBundleShortVersionString`: `0.2.60`
  - `CFBundleVersion`: `137`
  - `PDTLatestFeatureSlug`: `durable-tooltip-repair`
- After fix, Computer Use on the rebuilt app showed gallery chip Help values:
  - `S`: `Select this item for import (S / Cmd-I)`
  - `C`: `Mark this item as a candidate (C)`
  - `X`: `Exclude this item from import (X / Cmd-Shift-X)`
  - `R`: `Toggle RAW companions for this item (R / Cmd-Option-R)`

## Known Gaps

- Computer Use verified the macOS accessibility Help values and rebuilt UI state. It does not provide a direct hover-only screenshot action, so the visible hover bubble is covered by the source guard that now requires `ShortcutHintBubble(text: helpText)`.

## Release

Shipped as `0.2.60` build `137` with feature slug `durable-tooltip-repair`.
