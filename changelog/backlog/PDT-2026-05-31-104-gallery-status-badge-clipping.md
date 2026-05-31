# PDT-2026-05-31-104 gallery status badge clipping

---
item_id: PDT-2026-05-31-104
title: Gallery status badge clipping
status: approved_for_implementation
target_version: 0.2.58
target_build: 135
target_feature_slug: gallery-status-badge-clipping
---

## User Request Summary

After the gallery density pass, the right side of the photo status badge is cut off. The clipping gets worse when zooming the grid in or out.

## Constraints

- Preserve the image-first gallery design from `0.2.57`.
- Keep each grid card to one metadata line below the photo.
- Keep S/C/X/D/R controls and status visible.
- Preserve keyboard and mouse selection behaviour.
- Avoid widening cards beyond their fixed grid columns.

## Implementation Intent

1. Make the rendered card width match the fixed grid column width.
2. Keep status overlays inside the image bounds at every column count.
3. Give long status text a bounded width with truncation instead of clipping.
4. Keep card padding internal to the grid column.
5. Update release metadata and focused verification.

## Test Conditions

- Focused review grid layout and selection tests still pass.
- App bundle builds successfully.
- Bundle metadata reports `0.2.58` build `135`.
- Visual review confirms the status badge no longer clips on the right edge when changing grid column count.

## Success Criteria

- Status badge remains fully visible inside each photo card.
- Zooming grid columns in and out does not push overlays past card bounds.
- Review cards still show only one metadata line under each photo.
- Release metadata records `0.2.58` build `135` and `gallery-status-badge-clipping`.

## Current Status

Implemented pending user review in `0.2.58` build `135`.
