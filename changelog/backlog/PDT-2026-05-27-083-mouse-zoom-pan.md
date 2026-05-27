# PDT-2026-05-27-083 mouse zoom and pan

item_id: PDT-2026-05-27-083
title: Mouse zoom and pan
status: proposed
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
