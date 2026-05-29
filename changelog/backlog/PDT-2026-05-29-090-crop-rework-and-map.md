# PDT-2026-05-29-090 crop-drag rework + straighten + map view (plan)

item_id: PDT-2026-05-29-090
title: Crop overlay/interaction rework, straighten, and map/location triage
status: planned
target_release_version: TBD (one slice per release)
target_feature_slug: crop-overlay-rework

## Status

PLAN awaiting go-ahead. User-selected scope from PDT-2026-05-29-089: crop fixes #1–5,
crop straighten (#7), and a map view with per-folder/section location assignment.
EXPLICITLY OUT for now: aspect-ratio presets (#6), zoom-convention changes (#8–9),
ratings/labels, EXIF overlay, histogram, focus-AI, best-of-burst, batch, filmstrip.
Framing: this is TRIAGE, not an editor — crop + map are triage aids, kept minimal.
All items are DESIGN.md design changes; this plan is the approval artifact.

## Slice A — Crop overlay & interaction rework (#1–5)

Goal: make the existing drag-crop feel right. No data-model or output change.
All work in the preview/compare canvas; crop stays non-destructive (writes versioned file).

Files:
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `LockedCompareCanvasView`
  (layers, mouse events, cursor rects) and `FullPhotoSheet` (keyboard: Enter/arrows).
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift` — `CropSelectionGeometry`
  (hit-testing, edge grab zones, nudge math).
- Tests: `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift` (+ CropServiceTests unaffected).

Work items:
- A1 Dim-outside mask: replace the inside-the-selection accent fill (`cropSelectionLayer`
  fillColor alpha 0.16) with a 4-rectangle (or even-odd path) ~50–55% black mask covering
  the area OUTSIDE the selection; selection interior renders at true brightness. Keep the
  accent stroke on the selection border.
- A2 Rule-of-thirds grid: add a `cropGridLayer` (CAShapeLayer) drawing 2 vertical + 2
  horizontal lines inside the selection at 1/3 and 2/3; thin, low-alpha white. Update with
  the selection in `updateCropSelectionLayer()`. (Single overlay; no cycling for now.)
- A3 Bigger / smarter hit targets: in `CropSelectionGeometry.dragMode`, add edge-band grab
  zones (full edge length × tolerance), not just corner/edge squares; raise base tolerance
  floor (e.g. min 10–12pt) and keep size-scaled cap. Verify cursor rects cover the new bands.
- A4 No punitive reject: in `mouseUp`, drop `NSSound.beep()` + reject-on-too-small; instead
  clamp a too-small drag to a minimum usable size, OR treat a near-zero drag (a click) as
  "clear selection" (no error, no beep). Remove `onManualCropRejected` beep path.
- A5 Keyboard: Enter commits the pending crop (route to existing save path); Esc already
  cancels; arrow keys nudge — move whole rect when interior is the active mode, resize the
  last-touched edge/corner otherwise; 1px step, Shift = 10px. Add to `FullPhotoSheet`'s
  `ReviewKeyInputView` handlers + a `CropSelectionGeometry.nudge(rect:by:mode:)` helper.

Tests: hit-target classification for edge bands; nudge math (clamping at image bounds);
mask/grid path geometry is deterministic given a selection rect.
Risk: LOW (interaction/visual only). Manual GUI pass required (drag, move, resize, nudge,
commit/cancel) since SwiftUI/AppKit gestures aren't unit-testable here.

## Slice B — Straighten (#7)

Goal: rotate-to-level then crop, still non-destructive. Heaviest slice (touches output +
manifest schema + geometry).

Files:
- `Sources/PhotoDiaryTriage/CropService.swift` — rotate the decoded `CGImage` by an angle
  (CoreImage `CIImage` rotate or CG context transform) BEFORE `cropping(to:)`; output the
  rotated-then-cropped image. Compute output pixel size from the rotated crop.
- `Sources/PhotoDiaryTriage/Models.swift` / crop manifest types — add `rotationDegrees`
  (Double, default 0) to `CropManifestEntry` (and the normalized-rect application path) so
  history records the angle. Backward-compatible decode (default 0 when absent).
- `Sources/PhotoDiaryTriage/CropGeometry.swift` — define the crop rect in the ROTATED image
  space; document the convention (rotate about image center, then axis-aligned crop in
  rotated coords).
- UI: `FullPhotoSheet` / canvas — an angle slider (e.g. −15°…+15°) and a drag-a-line
  "level the horizon" affordance that sets the angle; the preview image rotates live while a
  pending crop is open.
Tests: `CropServiceTests` — rotated crop produces expected output dims for known angle/rect;
rotationDegrees round-trips through the manifest.
Risk: MEDIUM–HIGH. Rotation + crop geometry is fiddly (coordinate flips, center-of-rotation,
output sizing); the live-rotate preview is new canvas work. Ship A first; do B as its own release.

## Slice C — Map view + location assignment (triage)

Goal: see where photos/walks are, and ASSIGN a location to a walk folder / day / cluster as
triage metadata. Map is a NEW optional view — grid stays primary (DESIGN.md §1 preserved).

Data:
- Per-file GPS already captured (`MediaMetadata.latitude/longitude`) and written to file
  manifests; walk has `walk_location` (string) in the walk manifest.
- Add an assignable location to a node/section: name string + optional coordinate. Persist on
  the session's walk metadata for the current session; for archive walks, write/update the
  walk `.md` manifest's `walk_location` (+ a coordinate field). Define a `LocationAssignment`
  model and a write path in `ManifestRenderer` / session mutation.

Files:
- New `Sources/PhotoDiaryTriage/MapView.swift` (SwiftUI `Map`, MapKit) — plot photo GPS
  points and/or walk centroids; cluster when zoomed out; tap a pin → select that walk/day.
- `AppState` — derive map annotations from visible/contextual media (GPS) and from archive
  walk manifests (centroid/location); an `assignLocation(_:to:)` mutation.
- Location-assign UI: extend `WalkDetailsPaneView` (already has a Location text field +
  `updateWalkMetadata`) and add an inline "Assign location" affordance on day/cluster/walk
  nodes; optional "drop a pin" when no GPS exists.
- Persistence: session path via existing walk metadata save; archive path via manifest
  rewrite (Markdown-only write — ties into the sync research item).
Tests: location assignment round-trips to/from the walk manifest; annotation derivation from
GPS is correct; no map interaction needed for unit tests.
Risk: MEDIUM. MapKit in SwiftUI is straightforward; the real work is the location-assignment
model + manifest write path and keeping the grid primary. Confirm a DESIGN.md amendment for
the new map navigation surface.

## Suggested order

A (low risk, directly fixes the complaint) → C (map/location, independent) → B (straighten,
heaviest). Each ships as its own versioned release with its own changelog item.

## Open questions for user

- A2: rule-of-thirds only, or also offer grid/golden overlays later? (Plan: thirds only now.)
- B: acceptable angle range (±15° typical)? Live-rotate preview, or angle slider only?
- C: assign location at which granularity — walk folder, day, and/or time-cluster? Should the
  map be a top-level mode (alongside Archive/Camera/Logs) or a panel within archive browsing?
