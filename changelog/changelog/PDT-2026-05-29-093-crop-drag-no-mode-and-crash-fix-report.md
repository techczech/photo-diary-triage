# PDT-2026-05-29-093 crop drag no-mode + crash fix — report

item_id: PDT-2026-05-29-093
status: implemented
shipped_release_version: 0.2.45
shipped_feature_slug: crop-drag-fixes
branch: feature/crop-overlay-rework (not merged, not pushed)

## Summary

Addresses two issues reported on 0.2.44: (1) the drag-crop required a "Drag Crop" mode
toggle — the user wants dragging to just create a crop; (2) a SIGABRT crash in
`resetCursorRects()`.

## Changes

- Removed the "Drag Crop" toggle in the single-photo preview. The crop canvas is always
  selection-enabled now: drag on the photo creates an adjustable crop, adjust by
  edges/corners/handles or arrow keys, then click "Crop" (or press Return) to apply;
  Escape or the × clears the selection. (Pan while zoomed is now via two-finger
  scroll/trackpad, since mouse-drag is always a crop in the preview.)
- Fixed the crash: `addCursorRect` raises an exception on empty/non-finite rects. Added
  `addValidatedCursorRect` (standardize + require finite, positive size) and only add crop
  cursor rects when the selection is larger than 1×1pt. This was triggered by the Slice A
  edge-band cursor rects on a degenerate/near-zero selection.
- Compare sheet keeps its existing toggle for now; the crash fix applies there too (shared
  `LockedCompareCanvasView`).

## Files changed

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — guarded `resetCursorRects` +
  `addValidatedCursorRect`; `FullPhotoSheet` always-on crop (removed `isManualCropEnabled`
  and the toggle), "Crop" button, Return commits / Escape clears.
- `APP_RELEASE.env` — 0.2.45 / build 122 / crop-drag-fixes.

## Verification

- `swift build` — passed.
- `./scripts/build_app_bundle.sh` — passed; installed to /Applications; version 0.2.45,
  slug crop-drag-fixes; codesign verified; launched and running.
- `swift test` — NOT run (CLT-only; XCTest unavailable).
- The crash path (resetCursorRects on degenerate selection) is now guarded; needs a manual
  GUI pass to confirm no crash when resizing handles across/past edges repeatedly.

## Known gaps / follow-up

- Pan-by-mouse-drag while zoomed is replaced by scroll/trackpad pan in the preview (mouse
  drag is always crop now). If you want mouse-drag pan back when zoomed, the alternative is
  to enable crop-drag only at fit (zoom ≈ 1) and pan-drag when zoomed — say the word.
- Compare sheet still uses a Drag Crop toggle (multi-image); can be unified later.

## Handoff — please test APP_VERSION 0.2.45

Open a photo (double-click). WITHOUT toggling anything, drag on the image — a crop
selection should appear immediately with the outside dimmed and a thirds grid. Adjust it
(drag edges/corners, or arrow keys), then click "Crop" or press Return to apply; press
Escape or the × to clear. Resize a handle past the opposite edge and drag around a lot to
confirm it no longer crashes.
