# PDT-2026-05-29-092 crop overlay & interaction rework — report

item_id: PDT-2026-05-29-092
status: implemented
shipped_release_version: 0.2.44
shipped_feature_slug: crop-overlay-rework
branch: feature/crop-overlay-rework (not merged, not pushed)

## Summary

Slice A of plan PDT-2026-05-29-090: reworked the drag-crop interaction in the preview/
compare canvas. Behaviour-preserving for the crop OUTPUT (still non-destructive, versioned);
only the on-screen interaction and overlay changed. Applies to both the single-photo preview
and the compare sheet (shared `LockedCompareCanvasView`).

## User-visible changes

- A1 The discarded area is now DIMMED (≈52% black mask outside the selection); the kept area
  shows at true brightness. Previously the kept area was tinted blue — the opposite of the
  convention.
- A2 A rule-of-thirds grid is drawn inside the crop selection.
- A3 Whole edges are grab zones (not just tiny squares); corners have larger targets; the
  base hit tolerance was raised (≈11–20pt). Cursors update to match (resize on edges/corners).
- A4 No more system beep / "drag a larger area" rejection. A click or too-small drag now
  clears silently; a too-small resize restores the previous valid selection.
- A5 Enter commits a usable pending crop; arrow keys move the pending crop rect (Shift = a
  larger step). Esc still cancels.

## Files changed

- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift` — `CropSelectionGeometry`:
  corner-first + full-edge-band hit testing (`dragMode`, new `edgeHitBands`), new
  `nudgedNormalizedRect`.
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `LockedCompareCanvasView`: new
  `cropMaskLayer` (dim outside) + `cropGridLayer` (thirds); `cropSelectionLayer` is now a
  border only; `updateCropSelectionLayer`/`clearCropSelection` rewritten; raised
  `cropHandleTolerance`; cursor rects for edge bands; `mouseUp` no longer beeps/rejects.
  `FullPhotoSheet`: Enter commits, arrows nudge the pending crop.
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift` — `cropDragModeUsesEdgeBandsAndCorners`,
  `cropNudgeClampsWithinImage`.
- `APP_RELEASE.env` — 0.2.44 / build 121 / crop-overlay-rework.

## Verification

- `swift build` — passed (only the pre-existing non-sendable `NSImage?` warning).
- `git diff --check` — (run at commit).
- `swift test` — NOT run (Command Line Tools only; XCTest unavailable). New tests are pure
  `CropSelectionGeometry` functions and must be run on a full-toolchain machine.
- `./scripts/build_app_bundle.sh` — passed; installed to `/Applications/PhotoDiaryTriage.app`;
  `CFBundleShortVersionString=0.2.44`, `PDTLatestFeatureSlug=crop-overlay-rework`;
  codesign verified; launched and running.

## Known gaps / follow-up

- Keyboard nudge moves the WHOLE rect; resizing edges by keyboard is not included (could add later).
- A5 keyboard (Enter/arrows) wired in the single-photo `FullPhotoSheet`; compare-sheet
  keyboard parity not added (compare crop has per-image pending rects).
- The dim/thirds/edge-grab changes need a manual GUI pass (gestures aren't unit-testable here).

## Handoff — please test APP_VERSION 0.2.44

Open a photo (double-click), enable Drag Crop, and verify: the area OUTSIDE the rectangle
dims while the inside stays bright; a thirds grid shows; you can grab any edge (not just the
squares) to resize; clicking without dragging just clears with no beep; arrow keys nudge the
rectangle and Enter saves the crop. Tell me if the dim level / grid / grab feel right, then
I'll move on to the map view (Slice C).
