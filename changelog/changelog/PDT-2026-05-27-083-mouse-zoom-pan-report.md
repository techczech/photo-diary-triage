# PDT-2026-05-27-083 mouse zoom and pan report

item_id: PDT-2026-05-27-083
status: implemented
shipped_release_version: 0.2.39
shipped_feature_slug: mouse-zoom-pan

## Summary

Preview and compare canvases now support normal pointer-based image navigation.
Users can zoom with Command-scroll, zoom with trackpad pinch, and pan a zoomed image by click-dragging it.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-27-083-mouse-zoom-pan.md`

## User-Visible Behavior

- Command-scroll zooms the image under the pointer.
- Trackpad pinch zooms the image under the pointer.
- Zoom changes from pointer gestures update the same zoom state shown in the toolbar.
- A zoomed image can be panned by click-dragging.
- The cursor changes to an open hand when drag-pan is available and a closed hand while panning.
- Drag Crop mode keeps priority over panning and keeps the crosshair cursor.
- Panning is clamped to the image bounds.
- Visible-crop tracking is republished after pointer zooming and panning.

## Verification

- `swift build` passed.
- `swift test --filter canvasZoomMath` did not run because the local Command Line Tools setup reports `error: XCTest not available`.

## Known Gaps

- Manual pointer verification is still needed in the final installed app pass.
- The next chunk covers broader responsiveness and a Computer Use check.
