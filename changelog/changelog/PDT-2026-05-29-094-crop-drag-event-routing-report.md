# PDT-2026-05-29-094 crop drag event routing — report

item_id: PDT-2026-05-29-094
status: implemented
shipped_release_version: 0.2.46
shipped_feature_slug: crop-drag-event-routing
branch: feature/crop-overlay-rework (not merged, not pushed)

## Summary

Fixes "dragging shows literally nothing" reported on 0.2.45. The crop overlay never
appeared because mouse events never reached the crop logic.

## Root cause

Crop/pan mouse handlers were on `LockedCompareCanvasView` (an `NSScrollView`), but the
document view was a plain `NSImageView` (an `NSControl`) that swallows `mouseDown` via cell
tracking and does not forward it. The scroll view's `mouseDown`/`mouseDragged`/`mouseUp`
overrides therefore never ran, so `manualCropDocumentRect` was never set and none of the
crop layers (mask, grid, border, handles) were ever drawn. This also explains why crop-drag
could not be GUI-verified in prior sessions and why the prior dim/grid work appeared to do
nothing.

## Fix

- Added `CropCanvasImageView: NSImageView` as the document view; it overrides the mouse
  events and forwards them to `handleCanvasMouseDown/Dragged/Up` on the canvas (no `super`
  call, so cell tracking no longer eats the event).
- Renamed the canvas's mouse-handler bodies to `handleCanvasMouse*`; kept the `override`
  methods as thin forwarders.
- `imageView` is now a `CropCanvasImageView` wired with `eventHandler = self`.

Net: dragging on the photo now actually creates/updates the crop selection, so the dim
mask + rule-of-thirds grid + border + handles render live during the drag. Pointer pan
(when zoomed) now receives events too.

## Files changed

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `CropCanvasImageView`; canvas
  mouse handlers refactored to `handleCanvasMouse*`; document view swapped + wired.
- `APP_RELEASE.env` — 0.2.46 / build 123 / crop-drag-event-routing.

## Verification

- `swift build` — passed.
- `./scripts/build_app_bundle.sh` — passed; installed 0.2.46; codesign verified; launched
  and running.
- `swift test` — NOT run (CLT-only). This is an AppKit event-routing fix that can only be
  confirmed by a manual GUI drag.

## Handoff — please test APP_VERSION 0.2.46

Open a photo and drag on it (no toggle): a crop rectangle should appear immediately, with
the area outside it dimmed and a rule-of-thirds grid inside. Adjust by dragging edges/
corners or with arrow keys, then click "Crop" or press Return to apply; Escape or × clears.
If you still see nothing on drag, tell me and I'll instrument it further.
