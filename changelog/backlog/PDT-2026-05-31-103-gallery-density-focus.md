# PDT-2026-05-31-103 gallery density focus

---
item_id: PDT-2026-05-31-103
title: Gallery density focus
status: approved_for_implementation
target_version: 0.2.57
target_build: 134
target_feature_slug: gallery-density-focus
---

## User Request Summary

Improve the Camera Triage gallery so the photographs are the first visual focus. Each picture should have only one line of text underneath, and the app should waste less vertical space by moving controls such as tabs upward where practical.

## Constraints

- Preserve keyboard-driven triage and mouse selection behaviour.
- Preserve visible inclusion/exclusion state and shortcut affordances.
- Keep review grid browsing responsive and non-overlapping.
- Do not remove preview, compare, map, filter, or grid controls.
- Keep the design macOS-native and compatible with the current SwiftUI structure.

## Implementation Intent

1. Reduce review card chrome so image area dominates each card.
2. Collapse per-photo text into one compact line under each image.
3. Move decision/status markers onto the photo or into the same compact line instead of adding extra rows.
4. Move main workspace tabs into the window toolbar/title area when available.
5. Tighten gallery padding and grid spacing without harming selection clarity.

## Test Conditions

- Focused review interaction tests still pass.
- App bundle builds successfully.
- Manual visual pass confirms the gallery starts higher, photos occupy more vertical space, and each photo has one text line below it.

## Success Criteria

- Camera Triage cards show a single metadata line below each photo.
- Included/excluded/candidate/selected state remains visible.
- Top mode tabs no longer consume their own row inside the main content.
- Review controls remain available near the top of the gallery.
- Release metadata records `0.2.57` build `134` and `gallery-density-focus`.

## Current Status

Implemented pending user review in `0.2.57` build `134`.
