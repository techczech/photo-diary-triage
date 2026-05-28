# PDT-2026-05-27-082 drag crop affordances report

item_id: PDT-2026-05-27-082
status: implemented
shipped_release_version: 0.2.38
shipped_feature_slug: drag-crop-affordances

## Summary

Drag Crop now behaves like an explicit mouse tool instead of a hidden action.
The user gets active-mode feedback before dragging, visible crop/bounds feedback while in the canvas, Escape cancellation, and a status message when a too-small drag is rejected.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `changelog/backlog/PDT-2026-05-27-082-drag-crop-affordances.md`

## User-Visible Behavior

- Enabling Drag Crop sets a status message explaining that dragging over the image will create a crop.
- Escape exits Drag Crop mode first instead of immediately closing the preview or compare sheet.
- Crop mode uses a crosshair cursor over the image.
- The visible crop boundary stays drawn in Drag Crop mode, even when the full image is visible.
- The drag rectangle is shown during the drag.
- Too-small drags no longer fail silently; the app beeps and reports that a larger crop area is needed.
- Valid manual drags continue through the existing save path, which focuses the crop output and reports that the cropped version is shown.

## Verification

- `swift build` passed.
- `swift test --filter cropGeometryMapperMarksTinyManualDragUnusable` did not run because the local Command Line Tools setup reports `error: XCTest not available`.

## Known Gaps

- Manual visual verification still belongs in the final installed-app pass after mouse zoom/pan and responsiveness work.
- Mouse wheel/pinch zoom and click-drag panning are tracked separately in `PDT-2026-05-27-083`.
