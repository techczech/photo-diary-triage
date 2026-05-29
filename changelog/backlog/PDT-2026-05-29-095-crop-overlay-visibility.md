# PDT-2026-05-29-095 crop overlay not visible — instrumentation + layer reattach

item_id: PDT-2026-05-29-095
title: Crop overlay invisible during drag — diagnose + fix
status: implemented_pending_review
target_release_version: 0.2.47
target_feature_slug: crop-overlay-debug

## User report (0.2.46)

Drag now functionally crops (crop applies after drag; Crop-to-zoom works), but there is
NO visual feedback during the drag — no dim, no border, no grid, nothing.

## Diagnosis

Events now reach the crop logic (confirmed: the crop applies), so the failure is purely in
RENDERING the overlay. The overlay is CAShapeLayers added as sublayers of the
`NSImageView`'s backing layer; `NSImageView` may rebuild its layer when its image/contents
change, orphaning the sublayers (or stacking the image above them).

## This build (0.2.47)

- Likely fix: `ensureCropLayersAttached()` re-adds the overlay layers to the image view's
  current backing layer, sets explicit z-order, and updates frames; called from init,
  `updateImageLayout`, and `updateCropSelectionLayer`.
- Instrumentation: writes a diagnostic line to `/tmp/photodiary-crop-debug.log` on each
  mouse-down (reset) and each overlay update — records whether events arrive, the computed
  rect, whether the mask layer is attached to the current host layer, sublayer count,
  hidden/opacity, and frame vs image bounds. This tells us definitively whether the layers
  are attached and sized but not compositing (→ switch to a draw-based overlay view) or
  detached/zero-size (→ the reattach fixes it).

## Next step

User does one drag in the photo preview; agent reads `/tmp/photodiary-crop-debug.log` to
confirm the fix or pinpoint the remaining cause. The debug log + reattach are temporary
scaffolding to be removed/cleaned once the overlay renders.

## Status

implemented_pending_review on branch feature/crop-overlay-rework; APP_VERSION 0.2.47.
