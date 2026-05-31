# PDT-2026-05-31-110 card chrome clipping sidebar icon help report

---
item_id: PDT-2026-05-31-110
title: Card chrome clipping and sidebar icon help
status: implemented
app_version: 0.2.64
app_build: 141
feature_slug: card-chrome-clipping-sidebar-icon-help
completed_at: 2026-05-31T21:46:55Z
---

## Summary

Gallery card chrome now stays inside each card. Selection and focus outlines use inset strokes, so the blue selected outline does not bleed into the neighbouring card.

Copied/imported cards now show one status badge for the same copied state. When a detailed log or copied badge is already shown in the lower card chrome, the duplicate top-right copied pill is suppressed.

Icon-only top controls now have more durable Help coverage. The existing toolbar Help bridge also installs hover tracking on the nearest toolbar host, and inspector/sidebar icon-only buttons use the same shortcut-help path as other icon controls.

## User-Visible Behaviour

- Selected cards keep the blue outline inside the card boundary.
- Copied status appears once per copied item.
- Source, Settings, Open, Compare, Inspector, Shortcuts, More, and the left sidebar toggle expose Help.
- The inspector close icon and collapsed inspector rail icon expose Help.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentInspectorViews.swift`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-31-110-card-chrome-clipping-sidebar-icon-help.md`
- `changelog/backlog.jsonl`

## Verification

- Passed: `swift test --filter mainToolbarDoesNotInstallDuplicateSidebarButton`
- Passed: `swift test --filter ReviewInteractionTests` with 89 tests.
- Built: `./scripts/build_app_bundle.sh`
- Verified bundle metadata:
  - `CFBundleShortVersionString=0.2.64`
  - `CFBundleVersion=141`
  - `PDTLatestFeatureSlug=card-chrome-clipping-sidebar-icon-help`
- Verified with Computer Use:
  - The rebuilt app showed `v0.2.64 · card-chrome-clipping-sidebar-icon-help`.
  - The 2026 / 05 - May Camera Triage grid showed the selected outline inside the card, without overlapping the neighbouring card.
  - Copied cards showed a single lower `Copied` badge, not a duplicate top-right copied pill.
  - Icon-only top controls exposed Help: Source, Settings, Open, Compare, Inspector, Shortcuts, More, and the left sidebar toggle.

## Known Gaps

No remaining gaps observed in this pass.

## Handoff

Test `0.2.64` build `141`. In Camera Triage, open `2026 / 05 - May`, select copied and logged cards, and hover the icon-only top controls. The selected outline should stay inside the selected card, copied status should appear once, and icon-only controls should show Help.
