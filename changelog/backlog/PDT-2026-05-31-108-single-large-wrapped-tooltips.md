# PDT-2026-05-31-108 single large wrapped tooltips

---
item_id: PDT-2026-05-31-108
title: Single large wrapped tooltips
status: awaiting_user_review
target_version: 0.2.62
target_build: 139
target_feature_slug: single-large-wrapped-tooltips
---

## User Request Summary

The gallery now shows two tooltips at once: the custom shortcut bubble and the native macOS tooltip. Tooltips should appear as one larger, wrapped tooltip.

## Constraints

- Keep only one visible tooltip for shortcut-hinted controls.
- Make tooltip text larger and wrap cleanly.
- Avoid reintroducing native `.help` duplication on controls that already use the custom shortcut tooltip.
- Preserve action-specific tooltip copy from `0.2.60`.
- Verify the rebuilt macOS app with Computer Use before reporting completion.

## Implementation Intent

1. Update the shared `ShortcutHintModifier` so it renders the single visible tooltip.
2. Remove native `.help` from the triage chip wrapper where `shortcutHint` already supplies the visible tooltip.
3. Keep accessibility hint text on shortcut-hinted controls.
4. Add regression coverage that `shortcutHint` does not install `.help` and that the custom bubble uses larger wrapped text.
5. Build, launch, and verify the app.

## Test Conditions

- Focused tooltip tests pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.62` build `139`.
- Computer Use verifies the rebuilt app and action-specific controls remain present.

## Success Criteria

- Hovering a shortcut-hinted control shows one custom tooltip, not a native duplicate.
- Tooltip text is larger and wraps within a bounded width.
- S/C/X/D/R action tooltip text remains action-specific.

## Current Status

Implemented pending user review in `0.2.62` build `139`.
