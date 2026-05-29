# PDT-2026-05-29-095 crop overlay visibility — report

item_id: PDT-2026-05-29-095
status: implemented
shipped_release_version: 0.2.48
shipped_feature_slug: crop-overlay-fix
branch: feature/crop-overlay-rework (not merged, not pushed)

## Summary

Fixes "no visual feedback during crop drag" (0.2.46). User confirmed the overlay now
renders during the drag.

## Root cause (confirmed via instrumentation)

The crop overlay (dim mask, rule-of-thirds grid, border, handles) is built from CAShapeLayers
added as sublayers of the `NSImageView` backing layer. `NSImageView` rebuilds/replaces its
backing layer when its image/contents change, orphaning those sublayers — so paths were set
on detached layers and nothing drew, even though the crop geometry was correct (the crop
applied fine on commit). The /tmp debug log captured: events arriving, the correct drag rect,
and — after the fix — `attached=true, maskHidden=false, maskFrame=imgBounds`, confirming the
overlay was attached and sized once re-attachment was enforced.

## Fix

- `ensureCropLayersAttached()` re-adds the five overlay layers to the image view's CURRENT
  backing layer, sets explicit z-order (40–53) and frame, and is called from init,
  `updateImageLayout`, and `updateCropSelectionLayer`. This keeps the overlay attached and on
  top regardless of NSImageView rebuilding its layer.

## Cleanup

- 0.2.47 was a diagnostic build (temporary `/tmp/photodiary-crop-debug.log` logging). 0.2.48
  removes all the debug logging (`logCropDebug` and its call sites); only the real fix
  (`ensureCropLayersAttached`) remains. The temp log file is deleted.

## Files changed

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `ensureCropLayersAttached()`;
  removed debug logging.
- `APP_RELEASE.env` — 0.2.48 / build 125 / crop-overlay-fix.

## Verification

- `swift build` — passed.
- `./scripts/build_app_bundle.sh` — passed; installed 0.2.48; codesign verified; running.
- User-confirmed: overlay (dim + grid + border) now visible during drag.

## Net state of the crop drag (Slices A + fixes)

Drag on a photo (no mode) → adjustable crop selection appears with the discarded area dimmed
and a rule-of-thirds grid → adjust by edges/corners/handles or arrow keys → click "Crop" or
press Return to apply (non-destructive) → Escape or × clears. Pointer events fixed; no crash;
overlay renders.

## Follow-up

- Compare sheet still uses a Drag Crop toggle (multi-image) — can be unified later.
- Pan-while-zoomed in the preview is via scroll/trackpad (mouse-drag is always crop).
- Remaining plan items: Slice C (map/location), Slice B (straighten).
