# PDT-2026-05-31-105 computer verified gallery status

---
item_id: PDT-2026-05-31-105
title: Computer verified gallery status
status: approved_for_implementation
target_version: 0.2.59
target_build: 136
target_feature_slug: computer-verified-gallery-status
---

## User Request Summary

The `0.2.58` status badge clipping fix did not visibly change the Camera Triage gallery. Use Computer Use to verify the running app before declaring the result fixed.

## Constraints

- Verify the real running macOS app with Computer Use before and after the code change.
- Preserve image-first gallery layout and one metadata line under each photo.
- Avoid long right-edge status labels that can be clipped by grid columns.
- Preserve visible S/C/X/R decision controls and keyboard behaviour.
- Keep release tracking current.

## Implementation Intent

1. Use Computer Use to reproduce the visible Camera Triage status clipping.
2. Remove or compact the duplicated long right-edge decision status label in grid cards.
3. Keep decision state visible through active S/C/X chips and secondary badges.
4. Build and launch the app.
5. Use Computer Use to verify the gallery after changing grid zoom.

## Test Conditions

- Focused review grid tests still pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.59` build `136`.
- Computer Use verifies the Camera Triage gallery in the rebuilt app.

## Success Criteria

- No long right-edge `Undecided` status pill is clipped in Camera Triage.
- S/C/X/R controls remain visible over each photo.
- Grid zoom changes do not create cut-off status text at card edges.
- Release metadata records `0.2.59` build `136` and `computer-verified-gallery-status`.

## Current Status

Implemented pending user review in `0.2.59` build `136`.
