# PDT-2026-05-29-089 crop and culling UX improvements (proposal)

item_id: PDT-2026-05-29-089
title: Crop-drag rework + culling UX improvements
status: proposed
target_release_version: TBD
target_feature_slug: crop-drag-rework

## Status

PROPOSAL ONLY — research + options for discussion. Nothing here is approved.
All crop/zoom/selection/rating items are design changes under DESIGN.md and need
explicit approval (and likely a DESIGN.md amendment) before implementation.

## Why

User feedback: the crop drag interaction is "still not good enough." This documents
what the current crop drag actually does, why it falls short of the conventions in
Lightroom / Photoshop / Apple Photos / Capture One, and what else could improve the
triage app overall, grounded in how pro culling tools work (Photo Mechanic, Narrative
Select, FastRawViewer).

## Current crop/drag behavior (from code, v0.2.43)

- Crop lives only inside the full-photo preview / compare sheet; you must double-click
  to open preview first. (`FullPhotoSheet` → `FullPhotoPreviewCanvas` → `ZoomableImageCanvas`
  → `LockedCompareCanvasView`.)
- Crop is MODAL: you flip a "Drag Crop" toggle on before you can drag. Pan and crop are
  mutually exclusive (crop mode replaces pointer-pan).
- Overlay draws a translucent ACCENT-BLUE fill INSIDE the selection (alpha 0.16) plus a
  stroke; the discarded area stays full brightness. (`cropSelectionLayer`.) No
  rule-of-thirds / compositional grid.
- Free-form only: no aspect-ratio presets, no lock, no Shift-to-constrain.
- 8 resize handles (corners + edges), hit tolerance 7–14px; only the small handle squares
  resize (edges between handles are not grab zones). (`CropSelectionGeometry`,
  `cropHandleTolerance`.)
- No straighten / rotation angle.
- No keyboard nudge of crop bounds. Esc cancels; "V" / Save Crop commits (no Enter-to-commit).
- Too-small selection on mouse-up → `NSSound.beep()` + reject + restore.
- Zoom = Cmd+scroll or pinch; plain scroll = pan; toolbar +/- in 0.25 steps, range 0.25–4.
  No double-click-to-zoom, no spacebar loupe, no fit/100% toggle, no Z key.
- Crop is non-destructive: writes a new versioned output file. (KEEP — this is good.)

## Critique A — fix the crop drag that exists (highest priority)

A1. Invert the overlay: DIM the discarded area (≈50–60% black mask outside the rect),
    keep the selected area at true brightness. Current behavior tints the kept area blue,
    discoloring exactly what the user is judging. (Universal convention.)
A2. Add a rule-of-thirds grid inside the selection (optionally cycle overlays). Standard
    in every crop tool; aids composition decisions.
A3. Bigger / smarter hit targets: make full edges grab zones (not just tiny squares),
    widen corner targets, keep the cursor changes. Small handles are fiddly.
A4. Make crop less modal: allow starting a crop drag without a separate toggle when in a
    dedicated crop mode, and don't beep-reject tiny drags — clamp to a minimum size or
    treat a click as "clear selection" instead of an error.
A5. Enter commits, Esc cancels, arrow keys nudge the selected edge/whole rect by 1px
    (Shift = 10px). Matches platform expectations.

## Critique B — crop features pros expect (medium priority)

B1. Aspect-ratio presets + lock: Original, Free, 1:1, 3:2, 4:3, 5:4, 16:9, and orientation
    flip (X). Shift-drag constrains. Most-used pro crop control; currently absent.
B2. Straighten: drag-an-angle-line "level the horizon" tool, plus a fine angle slider.
B3. Persist last-used ratio across crops in a session.

## Critique C — zoom / pan / loupe navigation (medium)

C1. Adopt platform zoom conventions: double-click image toggles fit↔100%; Z or spacebar
    toggles loupe/100%; hold-space = temporary zoom; plain scroll/trackpad zoom (pinch
    already works). Cmd+scroll-only is non-obvious.
C2. Allow >100% (current cap 4x with 0.25 steps is coarse for sharpness checks); show the
    zoom % and a fit/100%/200% quick menu.
C3. "Zoom to same point" already exists in compare (Lock Pan) — extend the loupe in single
    preview to remember zoom point when stepping photo-to-photo.

## Critique D — broader culling/triage features (from pro-tool research)

D1. Star ratings (1–5) + color labels alongside S/C/X. Photo Mechanic's core speed model
    is rate-and-advance; S/C/X is only 3-state. (Big design change.)
D2. Loupe metadata/EXIF overlay (shutter, aperture, ISO, lens, focal length, date) toggled
    over the image — faster than the side inspector during fast culls.
D3. Histogram + highlight/shadow clipping warnings in the loupe (FastRawViewer staple) to
    cull over/under-exposed frames quickly.
D4. Focus / sharpness assist: at minimum an instant 100% loupe centered on the frame (or on
    detected faces); stretch: AI eyes-open / focus scoring (Narrative Select) — large effort.
D5. "Best of burst" suggestion: the app already groups bursts/time-clusters; surface a
    suggested keeper per burst to speed culling.
D6. Batch apply: rating / crop / RAW-toggle across the current multi-selection.
D7. Auto-advance after a decision (confirm current S behavior; extend to C/X) for rate-and-move flow.
D8. Map view for GPS-tagged photos (lat/long already in metadata).
D9. Customizable shortcuts (cheat sheet already exists).

## Suggested sequencing (if approved)

1. Quick wins, no model change: A1 (dim mask), A2 (thirds grid), A3 (bigger targets),
   A5 (Enter/Esc/arrows), C1/C2 (zoom conventions), D2 (EXIF overlay).
2. Medium: B1 (aspect presets+lock), B2 (straighten), D3 (histogram), D7 (auto-advance).
3. Big bets needing DESIGN.md amendment: D1 (ratings/labels), D4 (focus AI), D5 (best-of-burst),
   filmstrip.

## Sources

- Lightroom crop overlays / aspect lock / straighten: focusphotoschool.com, thelenslounge.com, helpx.adobe.com
- Culling tools (Photo Mechanic / Narrative Select / FastRawViewer): aftershoot.com/blog/best-culling-software, narrative.so, imagen-ai.com
- Zoom/loupe conventions: jkost.com, helpx.adobe.com, Apple Photos/Quick Look docs
- Handle/aspect conventions: Figma crop docs, Cloudinary guides
