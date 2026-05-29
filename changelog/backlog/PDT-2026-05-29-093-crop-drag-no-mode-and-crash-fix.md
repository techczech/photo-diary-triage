# PDT-2026-05-29-093 crop drag: remove mode + fix cursor-rect crash

item_id: PDT-2026-05-29-093
title: Crop drag always-on (no mode) + resetCursorRects crash fix
status: approved_for_implementation
target_release_version: 0.2.45
target_feature_slug: crop-drag-fixes

## User report (0.2.44)

1. The drag-crop "does not work": user expects to START by dragging to select a crop,
   adjust it, then click a Crop button. There should be NO "Drag Crop" mode toggle —
   dragging on the photo should just create a crop selection.
2. The app crashed (`EXC_CRASH`/SIGABRT) in
   `LockedCompareCanvasView.resetCursorRects()` → `-[NSView addCursorRect:cursor:]`.

## Root cause (crash)

`addCursorRect:cursor:` raises an Objective-C exception on an empty / non-finite rect.
The Slice A edge-band cursor rects (and the open-hand rect on the selection) could be
empty for a degenerate/near-zero selection, so AppKit aborted during the cursor-rect
update cycle.

## Changes

- Remove the "Drag Crop" toggle in the single-photo preview (`FullPhotoSheet`): the crop
  canvas is now always selection-enabled (`isCropSelectionEnabled: true`). Drag on the
  photo creates an adjustable crop; adjust; click "Crop" (or press Return) to apply;
  Escape / the x clears the selection. Pan while zoomed is via two-finger scroll/trackpad
  (mouse-drag is now always crop in the preview).
- Guard every `addCursorRect` via `addValidatedCursorRect` (standardize + require finite,
  non-empty rect); only add crop cursor rects when the selection is larger than 1×1pt.
- Compare sheet keeps its existing toggle for now (multi-image); the crash fix applies to
  it too via the shared canvas.

## Files

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `LockedCompareCanvasView`
  (`addValidatedCursorRect`, guarded `resetCursorRects`); `FullPhotoSheet` (removed
  `isManualCropEnabled`/toggle; always-on crop; "Crop" button; Return/Escape wiring).

## Test conditions

- `swift build` passes; manual GUI pass: open preview, drag (no toggle) → selection
  appears, adjust by edges/handles/arrows, click Crop / Return to apply, Escape clears.
  Resize a handle past the opposite edge and across the image repeatedly — must NOT crash.

## Success criteria

- No mode toggle in the single-photo preview; drag immediately creates a crop.
- No crash from cursor-rect updates during crop interaction.

## Status

implementation_started on branch feature/crop-overlay-rework; ships as APP_VERSION 0.2.45.
