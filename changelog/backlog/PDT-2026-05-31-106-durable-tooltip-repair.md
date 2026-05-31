# PDT-2026-05-31-106 durable tooltip repair

---
item_id: PDT-2026-05-31-106
title: Durable tooltip repair
status: awaiting_user_review
target_version: 0.2.60
target_build: 137
target_feature_slug: durable-tooltip-repair
---

## User Request Summary

Tooltips have regressed in the gallery. The S/C/X/D/R controls should not show one-letter or generic inherited tooltips; all tooltips throughout the app should be correct and resistant to future UI layout changes.

## Constraints

- Research the current tooltip/help implementation before changing code.
- Put tooltip text on the actual interactive controls rather than relying on parent containers.
- Avoid reusable visual wrappers that silently install placeholder help text.
- Preserve image-first gallery layout, keyboard triage, and compact card chrome.
- Use Computer Use to verify the rebuilt macOS app before reporting completion.
- Keep release tracking current.

## Implementation Intent

1. Inspect all SwiftUI `.help` and shortcut hint usage.
2. Introduce a central tooltip text source for review/triage actions.
3. Ensure toolbar, gallery chips, and card selection surfaces use action-specific help text.
4. Remove one-letter placeholder tooltips from triage chip visuals.
5. Add focused regression coverage for tooltip strings and chip call sites.
6. Build, launch, and verify the app with Computer Use.

## Test Conditions

- Tooltip tests pass.
- Existing review interaction tests still pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.60` build `137`.
- Computer Use verifies that gallery chip help is action-specific, not `C` or generic selection help.

## Success Criteria

- S/C/X/D/R gallery controls expose clear action-specific tooltips.
- Parent selection surfaces no longer override child action tooltips.
- Tooltip strings are centralized enough to resist future visual wrapper/layout changes.
- Release metadata records `0.2.60` build `137` and `durable-tooltip-repair`.

## Current Status

Implemented pending user review in `0.2.60` build `137`.
