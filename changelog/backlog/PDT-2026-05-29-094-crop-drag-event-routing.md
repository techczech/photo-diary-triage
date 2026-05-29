# PDT-2026-05-29-094 crop drag event routing fix

item_id: PDT-2026-05-29-094
title: Crop drag produces no visual feedback — fix mouse event routing
status: approved_for_implementation
target_release_version: 0.2.46
target_feature_slug: crop-drag-event-routing

## User report (0.2.45)

Dragging on the photo shows "literally nothing — no border, no dimming, nothing."

## Root cause

The crop/pan mouse handling (`mouseDown`/`mouseDragged`/`mouseUp`) lived on
`LockedCompareCanvasView` (an `NSScrollView`). Mouse clicks land on its document view, a
plain `NSImageView` (an `NSControl`), which swallows the mouse-down through cell tracking
and never forwards it up the responder chain. So the scroll view's mouse overrides never
fired: `manualCropDocumentRect` was never set, no crop layers were ever drawn, and pointer
pan never engaged. This is why crop-drag could never be GUI-verified in earlier sessions.

## Fix

- New `CropCanvasImageView: NSImageView` document view that overrides
  `mouseDown/Dragged/Up` and forwards them to the canvas
  (`handleCanvasMouseDown/Dragged/Up`). It does not call `super`, so cell tracking no longer
  swallows the event.
- The canvas's former `override func mouse*` bodies are now `handleCanvasMouse*` methods;
  the overrides remain as thin forwarders.
- `imageView` is now a `CropCanvasImageView` with `eventHandler = self`.

This makes drag-crop (and pointer pan when zoomed in compare/preview) actually receive
events, so the dim mask / thirds grid / border / handles render during a drag.

## Files

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`.

## Test conditions

- `swift build` passes; manual GUI pass: open a photo, drag — selection + dim + grid must
  appear immediately; adjust; Crop/Return applies; Escape clears.

## Success criteria

- Dragging on the photo shows the crop selection (dim outside, thirds grid, border, handles).

## Status

implementation_started on branch feature/crop-overlay-rework; ships as APP_VERSION 0.2.46.
