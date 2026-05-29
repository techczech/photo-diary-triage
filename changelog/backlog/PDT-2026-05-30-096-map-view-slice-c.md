# PDT-2026-05-30-096 map view + location assignment (Slice C)

item_id: PDT-2026-05-30-096
title: Map panel in browsing + location assignment
status: approved_for_implementation
target_release_version: 0.2.49 (C.1)
target_feature_slug: map-panel

## Decisions (from user)

- Placement: a map PANEL in the browsing surface (grid stays primary, DESIGN.md §1).
- Assign location at: walk folder, day, time cluster, and individual photo.
- Purpose: BOTH plot GPS-tagged photos AND assign/edit a location (name + pin).

## Incremental delivery

- C.1 (this release 0.2.49): map panel + GPS plotting. Fix EXIF GPS sign handling; add a
  MediaItem coordinate accessor; add a toggleable inline map panel in the review pane that
  plots markers for the visible photos that have GPS, framed to their bounds, with an
  empty-state when none have GPS. No persistence change.
- C.2 (next): walk-level location assignment (name + dropped pin) reusing/extending
  walkMetadata.location, persisted via session save + manifest.
- C.3: day / time-cluster / individual-photo location assignment via a new
  per-target LocationAssignment model persisted on the session and written to manifests.

## C.1 scope (now)

- Fix `MetadataExtractor` to apply `kCGImagePropertyGPSLatitudeRef`/`LongitudeRef`
  (S → negative latitude, W → negative longitude). Extract a testable sign helper.
- Add `MediaItem.coordinate: CLLocationCoordinate2D?` (from metadata lat/long).
- New `MapPanelView` (SwiftUI `Map`, macOS 14 API) with a region-fitting helper.
- `ReviewPaneView`: a "Map" toggle in the review top bar that shows an inline fixed-height
  map panel above the grid; markers for visible items with coordinates; empty-state otherwise.

## Constraints

- Grid remains the primary review surface; the map is an optional inline panel.
- No change to crop, selection, or persistence in C.1.

## Test conditions

- `swift build`; unit test for the GPS sign helper (S/W negative, N/E positive, nil-safe).
- Manual GUI: toggle Map; pins appear for GPS photos; empty-state when none.

## Success criteria

- C.1: toggling Map shows correctly-placed pins for GPS-tagged photos in the current
  context; UK/west coordinates plot in the right place; grid unaffected.

## Status

C.1 implementation_started on branch feature/map-view; ships as APP_VERSION 0.2.49.
