# PDT-2026-05-30-096 map view (Slice C.1) — report

item_id: PDT-2026-05-30-096
status: implemented
shipped_release_version: 0.2.49
shipped_feature_slug: map-panel
branch: feature/map-view (not merged, not pushed)

## Summary

First slice of the map feature: an inline map panel in the review pane that plots the
photos in the current context that carry GPS coordinates. Also fixes a real GPS bug so
coordinates land in the right place.

## Changes

- GPS sign fix: `MetadataExtractor` now applies the EXIF hemisphere references
  (`GPSLatitudeRef`/`GPSLongitudeRef`) so South latitudes and West longitudes are negative.
  Previously the raw magnitude was used, so UK (west) longitudes would have plotted east of
  the prime meridian. Logic extracted to `MetadataExtractor.signedCoordinate(magnitude:ref:negativeRef:)`.
- New `MapPanelView` (SwiftUI `Map`, macOS 14 API): markers for each visible photo with a
  coordinate, framed to their bounding region, with a "N located" badge and an empty-state
  when no photo in the context has GPS.
- `ReviewPaneView`: a "Map" toggle button in the review top bar shows the map as an inline
  fixed-height (280pt) panel above the grid. Grid stays primary (DESIGN.md §1).

## Files changed

- `Sources/PhotoDiaryTriage/MetadataExtractor.swift` — GPS ref handling + `signedCoordinate`.
- `Sources/PhotoDiaryTriage/MapPanelView.swift` — new.
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift` — Map toggle + inline panel.
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift` — `gpsSignedCoordinateAppliesHemisphereRef`.
- `APP_RELEASE.env` — 0.2.49 / build 126 / map-panel.

## Verification

- `swift build` — passed.
- `./scripts/build_app_bundle.sh` — passed; installed 0.2.49; codesign verified; running.
- `swift test` — NOT run (CLT-only); the GPS sign helper has a unit test to run on a full
  toolchain.

## Known gaps / next

- GPS is only extracted in full session scans (`.full`); archive browsing uses
  `.fileAttributesOnly`, so the map is empty for archive context until we extract GPS there.
- Markers are not yet tappable-to-select; clustering not yet applied for dense walks.
- C.2 (next): assign a location (name + dropped pin) to the current walk, persisted.
- C.3: per day / time-cluster / individual-photo location assignment (new model + persistence).

## Handoff — please test APP_VERSION 0.2.49

Open a session/day with photos that have GPS (e.g. phone photos), click the new "Map"
button in the review toolbar: an inline map should appear above the grid with a pin per
located photo, framed to the area. If your photos have no GPS you'll see the empty-state —
that's expected; manual location assignment is the next slice. Confirm the panel placement
feels right (inline above the grid) before I add assignment.
