# PDT-2026-05-27-082 drag crop affordances

item_id: PDT-2026-05-27-082
title: Drag crop affordances
status: proposed
target_release_version: 0.2.38
target_feature_slug: drag-crop-affordances

## User Request

Make Drag Crop behave like a real mouse crop tool.

## Constraints

- Keep the existing SwiftUI surface.
- Use the smallest AppKit bridge inside the existing image canvas.
- Do not break keyboard navigation or normal grid selection.

## Implementation Intent

- Change cursor to crosshair in crop mode.
- Show crop-ready hover/boundary feedback.
- Show a clear selection rectangle while dragging.
- Support Escape to cancel crop mode.
- Decide whether mouse-up saves immediately or leaves a confirmable rectangle; make the state explicit either way.

## Test Conditions

- Mouse drag event test produces expected normalized crop.
- Too-small drag test does not crop.
- Cancel test clears selection and exits crop mode.
- Manual check for cursor, overlay, drag rectangle, and save feedback.

## Success Criteria

- User can tell crop mode is active before dragging.
- User can see the crop rectangle during drag.
- User gets clear feedback after crop creation or cancel.
- Crop mode does not accidentally swallow normal selection outside crop mode.
