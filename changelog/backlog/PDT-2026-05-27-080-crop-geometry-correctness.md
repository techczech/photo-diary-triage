# PDT-2026-05-27-080 crop geometry correctness

item_id: PDT-2026-05-27-080
title: Crop geometry correctness
status: proposed
target_release_version: 0.2.36
target_feature_slug: crop-geometry-correctness

## User Request

Fix crop output so it matches the image area the user sees or drags.

## Constraints

- Must be deterministic and tested before changing more UI.
- Keep non-destructive sibling crop output.
- Preserve existing crop manifest format where possible; extend only if useful.
- Geometry must work for preview and compare surfaces.

## Implementation Intent

- Extract a pure crop geometry mapper out of `LockedCompareCanvasView`.
- Use the mapper for visible viewport crop and manual drag crop.
- Make coordinate origin and y-axis handling explicit.
- Ensure `CropService` receives the same normalized rectangle represented by the on-screen crop area.
- Add a visible zoom crop boundary when `Crop Visible` is available.

## Test Conditions

- Unit tests for viewport to normalized rect.
- Unit tests for drag rect to normalized rect.
- Pixel fixture tests checking saved crop corner colours.
- Rotated image/manual verification if automated orientation fixture is not available.

## Success Criteria

- A centred visible area crops the centred image pixels.
- A manually dragged rectangle crops the dragged pixels.
- Top/bottom and left/right are not inverted.
- `Crop Visible` is disabled only when the visible area is full-frame.
