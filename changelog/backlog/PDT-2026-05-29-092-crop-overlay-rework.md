# PDT-2026-05-29-092 crop overlay & interaction rework (Slice A)

item_id: PDT-2026-05-29-092
title: Crop overlay & interaction rework (#1-5)
status: approved_for_implementation
target_release_version: 0.2.44
target_feature_slug: crop-overlay-rework

## Source

Slice A of the approved plan PDT-2026-05-29-090. User selected crop fixes #1–5 and asked
to start with this slice. Triage aid, not an editor; no crop-output/data-model change.

## Scope

- A1 Dim the discarded area (mask outside the selection) instead of tinting the kept area.
- A2 Rule-of-thirds grid inside the selection.
- A3 Bigger / smarter hit targets (full-edge grab bands + larger corners + higher floor).
- A4 Remove the punitive beep/reject on small drags (click clears; bad resize restores).
- A5 Enter commits the pending crop; arrow keys move the pending crop rect (Shift = larger step).

## Constraints

- DESIGN.md: crop stays in the preview/compare surface; no change to grid-first review.
- No change to crop output, manifest, or non-destructive versioning.
- Keyboard shortcuts scoped to the preview/compare surface only.

## Files

- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift` — `LockedCompareCanvasView`
  (mask + grid layers, mouseUp, cursor rects), `FullPhotoSheet` (Enter/arrow wiring).
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift` — `CropSelectionGeometry`
  (edge-band hit testing, nudge helper).
- Tests: `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`.

## Test conditions

- `swift build` passes; `swift test` (run where toolchain permits).
- New unit tests: edge-band dragMode classification; nudge clamps within [0,1].
- Manual GUI pass: open preview, Drag Crop, verify dim-outside + thirds grid, grab edges,
  click clears (no beep), Enter commits, arrows move the rect.

## Success criteria

- Discarded area dimmed, kept area true-colour, thirds grid visible during crop.
- Edges (not just tiny squares) grab and resize; corners easier to hit.
- No system beep on small/click drags.
- Enter commits; arrows nudge the pending crop.

## Status

implementation_started on branch feature/crop-overlay-rework; ships as APP_VERSION 0.2.44.
