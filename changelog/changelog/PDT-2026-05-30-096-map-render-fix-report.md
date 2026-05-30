# PDT-2026-05-30-096 map render fix + UX plan/walkthrough — report

item_id: PDT-2026-05-30-096
status: implemented
shipped_release_version: 0.2.51
shipped_feature_slug: map-render-fix
branch: feature/map-view (not merged, not pushed)

## User report (0.2.50)

"I don't see any map when I click the map icon — I should always see it." Plus: do a much
more detailed UX plan and a cognitive walkthrough BEFORE asking to test.

## Root cause

The `Map` view sat in a VStack inside a fixed-height panel without a fill frame, so it
collapsed to ~0 height and was invisible (the panel toggled, but the map area had no size).

## Fix

- Forced `maxWidth/maxHeight: .infinity` on the map, the map container, and the read-only
  empty-state, so the map fills the panel below the assignment row.

## Process change (as requested)

Authored a detailed design brief + cognitive walkthrough BEFORE asking to test:
- `design-plans/map-location-assignment/00-meta.md`
- `design-plans/map-location-assignment/01-design-brief.md`
- `design-plans/map-location-assignment/02-cognitive-walkthrough.md`
The walkthrough records the zero-height bug (found + fixed), the gesture fallback ("Pin to
map centre" because click→coordinate can't be author-verified), default-region behavior,
read-only/narrow-pane edges, and persistence — and lists open questions instead of assuming.

## Files changed

- `Sources/PhotoDiaryTriage/MapPanelView.swift` — fill frames.
- `design-plans/map-location-assignment/*` — new design docs.
- `APP_RELEASE.env` — 0.2.51 / build 128 / map-render-fix.

## Verification

- `swift build` — passed; bundle built; installed 0.2.51; codesign verified; running.
- `swift test` — NOT run (CLT-only).
- Author cannot GUI-verify map tile rendering; the fill fix addresses the most likely cause
  of "no map". If a blank tile area persists after this, it is a separate MapKit-rendering
  issue (noted as risk R-B in the brief).

## Handoff — please test APP_VERSION 0.2.51

Toggle "Map": a map should now fill the panel (it no longer collapses). In an editable
log, pan to your area, press "Pin to map centre" (guaranteed) or click the map, type a
location name, Save Location; reopen to confirm it persisted. Please also report whether
clicking directly on the map drops the pin, and answer the three open questions in
`02-cognitive-walkthrough.md`.
