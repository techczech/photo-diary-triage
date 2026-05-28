# PDT-2026-05-27-083 mouse zoom and pan

item_id: PDT-2026-05-27-083
title: Mouse zoom and pan
status: awaiting_user_review
target_release_version: 0.2.39
target_feature_slug: mouse-zoom-pan

## User Request

Add normal mouse and trackpad support for zooming and panning images.

## Constraints

- Preserve existing keyboard zoom and pan.
- Support preview and compare canvases.
- Avoid global shortcuts that interfere with grid navigation.
- Implement inside the existing AppKit-backed image canvas where pointer events already belong.

## Implementation Intent

- Add Command-scroll zoom.
- Add trackpad pinch zoom.
- Anchor zoom around the pointer when possible.
- Add click-drag pan when zoomed.
- Use open-hand/closed-hand cursor feedback for panning.
- Clamp pan to image bounds.

## Test Conditions

- Pure zoom state test for pointer-anchored zoom.
- Scroll-event test for Command-scroll zoom path.
- Magnify-event test where practical.
- Drag pan test checking viewport changes and clamping.
- Manual verification with trackpad and mouse.

## Success Criteria

- User can zoom with trackpad pinch.
- User can zoom with Command-scroll.
- User can pan by dragging a zoomed image.
- Crop visible area stays correct after mouse zoom and pan.

## Implementation Notes

- Canvas zoom is now a binding so AppKit pointer gestures update the same state as toolbar and keyboard zoom.
- Command-scroll zoom is handled inside the image canvas.
- Trackpad pinch zoom is handled through `magnify(with:)`.
- Pointer-anchored zoom keeps the same image point under the cursor where possible.
- Click-drag panning is enabled when the image is zoomed beyond fit and the crop tool is off.
- Cursor feedback switches between open-hand and closed-hand panning cursors; Drag Crop keeps the crosshair cursor.
- Pan origins are clamped to image bounds.
- Added deterministic zoom/pan math tests for pointer anchoring, pan clamping, and zoom range clamping.

## Verification

- `swift build` passed.
- `swift test --filter canvasZoomMath` blocked by local XCTest lookup failure: `error: XCTest not available`.
