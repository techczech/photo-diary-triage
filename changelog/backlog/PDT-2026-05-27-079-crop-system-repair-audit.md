# PDT-2026-05-27-079 crop system repair audit

item_id: PDT-2026-05-27-079
title: Crop system repair audit
status: repair_planned
target_release_version: analysis-only
target_feature_slug: crop-system-repair-audit

## User Request

Audit crop functionality in detail after installed `APP_VERSION=0.2.35` still fails real use.

User reports:

- crop output does not match the visible/centred crop area
- crop/original links are not clear or clickable enough
- crop and original are not adjacent in gallery
- drag crop lacks normal pointer affordances
- no visible crop boundary or mouse feedback
- no mouse zoom support with Command-scroll or trackpad pinch
- no click-drag panning support

## Constraints

- Use Build macOS Apps workflow.
- Treat this as a feature reset, not a small patch.
- Inspect actual code paths before proposing fixes.
- Break repair work into individual chunks.
- Each chunk must have expected functionality and tests.
- Do not present implemented status until code, backlog, changelog, and app release agree.

## Implementation Intent

- Review crop geometry from displayed image coordinates to pixel crop rectangle.
- Review crop output insertion, link navigation, crop/original grouping, and gallery ordering.
- Review crop interaction affordances in preview and compare surfaces.
- Review image zoom and pan mouse support.
- Produce a detailed repair plan with testable chunks.

## Test Conditions

- Static trace to concrete files and symbols.
- Identify deterministic unit tests for geometry and state.
- Identify manual UI verification for cursor, drag boundary, zoom, and pan.
- Run build/tests only if implementation begins in a follow-up slice.

## Success Criteria

- User gets a clear diagnosis of what is wrong and why.
- Each missing or weak feature has an independent repair chunk.
- Each chunk has acceptance criteria and tests.
- Tracking contains enough detail to implement without re-litigating scope.

## Audit Findings

### 1. Crop Geometry Is Not Trustworthy Yet

- `Crop Visible` and `Drag Crop` both depend on `LockedCompareCanvasView.normalizedCropRect`.
- That mapper is private UI code, not a tested product contract.
- It mixes AppKit scroll-view bounds, `NSImage.size`, image-view bounds, and a y-axis flip.
- `CropService` then applies the normalized rectangle to an orientation-applied `CGImage`.
- There is no deterministic test that proves the visible viewport maps to the same pixels written to disk.
- There is no test with a recognisable pixel fixture where the saved crop is checked against the displayed centre.
- This matches the user report that a carefully centred visible area does not become the saved crop.

### 2. Crop Links Exist But Are Not Reliably Clickable

- Grid cards render `CropRelationshipBadge` as a button.
- The same card then overlays a full-card `ReviewGridClickTarget`.
- `ReviewGridClickView.hitTest` always returns itself.
- That can eat badge clicks and make the badge look clickable without opening the linked crop/original.
- Preview and compare surfaces have crop badge buttons, but the gallery surface is the user's main decision surface and is currently not reliable.
- Inspector crop history exists in `0.2.35`, but it is too indirect and depends on the inspector being visible.

### 3. Crop/Original Gallery Grouping Is Weak

- Sorting only groups crop families when `capturedAt` values are exactly equal.
- After a rescan, crop metadata can be missing or different, so the crop can float away from the original.
- Current crop sort priority puts crops before the original.
- User expectation is original first, then crop versions directly beside it.
- The screenshot shows exactly this failure mode: crop and source relationship is visible only as separated badges, not as an adjacent family.

### 4. Drag Crop Lacks Desktop Affordances

- `Drag Crop` is a toggle, but the canvas gives little state feedback before the drag starts.
- No cursor change.
- No hover frame or crop-mode boundary.
- No persistent selection rectangle after mouse-up.
- No cancel/escape affordance for crop mode.
- The selection layer exists only during the drag and is not enough for a normal image-editing interaction.

### 5. Mouse Zoom And Pan Are Incomplete

- Zoom exists through toolbar buttons and keyboard shortcuts.
- Panning exists through keyboard commands and scrollbars.
- There is no `magnify(with:)` support for trackpad pinch.
- There is no Command-scroll zoom.
- There is no click-drag pan for a zoomed image.
- There is no cursor change for pan state.
- These are AppKit-level behaviours and should stay in the existing `NSViewRepresentable` bridge.

## Repair Chunks

### PDT-2026-05-27-080 Crop Geometry Correctness

Goal: saved crop must match the visible or dragged area.

Functionality:

- Extract crop mapping into a pure `CropGeometryMapper`.
- Use one coordinate contract for visible viewport, manual drag, and pixel crop output.
- Account for image orientation, displayed image size, scroll offset, zoom scale, and top-left pixel coordinates.
- Show a visible crop boundary for the current `Crop Visible` area when zoomed.
- Persist enough manifest detail to diagnose crop rectangle later.

Tests:

- viewport-centred fixture maps to expected normalized rectangle.
- manual drag top-left to bottom-right maps to expected normalized rectangle.
- y-axis regression test where top and bottom colours differ.
- service output pixel test: crop a colour-grid image and assert saved crop corner colours.
- rotated-image fixture test before shipping if local image tooling permits.

### PDT-2026-05-27-081 Crop Links And Gallery Grouping

Goal: original and crops must behave as one visible family in the app.

Functionality:

- Make original first, then crop versions.
- Keep crop families adjacent even if crop metadata is missing or differs after rescan.
- Provide a clear in-card link action that is not hidden behind a full-card click overlay.
- Let grid, preview, compare, and inspector all switch to linked crop/original versions.
- Make current version obvious.

Tests:

- gallery ordering test with original/crops that have mismatched or nil `capturedAt`.
- crop family ordering test: original first, then crops in manifest order.
- grid action routing test or AppKit hit-test test proving badge/button clicks are not swallowed by card selection.
- state test for opening original from crop and crop from original without changing filters unexpectedly.

### PDT-2026-05-27-082 Drag Crop Affordances

Goal: drag crop must feel like a real crop tool.

Functionality:

- Entering Drag Crop mode changes cursor to crosshair over the image.
- Hover state shows crop-ready boundary or subtle overlay.
- Dragging shows a visible selection rectangle with fill, outline, and dimensions if useful.
- Mouse-up either saves immediately with explicit feedback or leaves a confirmable crop rectangle.
- Escape cancels drag crop mode.
- Crop mode exits predictably after crop save or cancel.

Tests:

- `LockedCompareCanvasView` mouse-down/drag/up test calls `onManualCrop` with expected rect.
- too-small drag test does not save crop and gives clear status.
- cancel test clears crop mode and selection layer.
- manual verification: cursor, overlay, drag rectangle, and completion feedback.

### PDT-2026-05-27-083 Mouse Zoom And Pan

Goal: preview and compare must support normal Mac image navigation.

Functionality:

- Command-scroll zooms in/out.
- Trackpad pinch zooms in/out.
- Zoom anchors around pointer location when possible.
- Click-drag pans a zoomed image.
- Cursor changes to open hand/closed hand for pan.
- Existing keyboard zoom and pan keep working.

Tests:

- pure zoom/pan state tests for pointer-anchored zoom.
- scroll event test for Command-scroll zoom path.
- magnify event test for pinch path where practical.
- drag pan test checks viewport origin changes and clamps to bounds.
- manual verification on trackpad and mouse.

## Implementation Order

1. `080` first, because crop output correctness is the core trust issue.
2. `081` second, because users must see and switch between related versions.
3. `082` third, because drag crop should be understandable before adding more input paths.
4. `083` fourth, because zoom/pan depends on the same geometry contract as crop.
