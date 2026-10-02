---
item_id: PDT-2026-10-02-102
title: Archive-wide Map and explicit travel viewing
status: shipped_pending_native_check
target_release_version: 0.7.6
target_build: 142
target_feature_slug: archive-map
---

# Archive Map

The approved completion plan requires a clustered pin for every located Walk across the archive, using the pinned index and opening the existing Walk/Trip route. Add Map alongside Timeline and Contact Sheet. A canonical Walk pin takes precedence; otherwise use the spherical centroid of complete, finite photo GPS pairs. Preserve coordinate provenance and reject out-of-range/partial pairs. Year, entry-type and search filters must affect map coverage. List unlocated Walks so absence is visible. Keep archive map state separate from the active Photo Log.

Native MapKit clusters Walk annotations; selecting a cluster zooms into its members, selecting a Walk opens its existing photo grid. No image/original reads are required. Test relocated index-only roots, antimeridian GPS, pin precedence, invalid pairs, filter behaviour and actual AppState navigation with an unrelated active log.

ADR0002 and WP2 require an explicit Download to view before any travel original-byte read, including resident originals. Correct the old availability-only full-view gate: keep scoped, in-memory explicit grants, deny implicit archive reads, never preheat archive originals, and clear grants on policy changes. Explicit downloading stays inside Walkfolio, validates archive containment and uses injected download/readiness behaviour in tests. FileProvider behaviour is separately native-verified; no live hydration while the reviewer is away.

This slice delivers Map browsing and canonical coordinate projection. Contextual per-photo/cluster override editing remains the next location slice, followed by descriptions and album delivery. The full approved scope is retained.

## Implementation checkpoint

Map projects Walk pins or original-photo GPS centroids from index metadata, clusters with MKMapView and opens existing Walk routes. Invalid/partial pairs are rejected; crop derivatives do not bias the centroid; legacy provenance remains unknown. An unrelated open Photo Log cannot supply the Archive pin. Covers accept only validated _index thumbnail paths.

Travel viewing is explicitly granted per path after availability succeeds. FileProvider materialisation remains inside the app; all request/readiness work has a deadline and cancellation bridge. Policy generations reject stale callbacks/decodes, and cached originals cannot bypass revoked consent. Index thumbnails remain readable; preheat and implicit thumbnail generation stay denied after a grant. EXIF extraction also obeys the read guard.

Full suite: 249 tests in two suites passed in 11.711 seconds. Native Map clustering and actual OneDrive materialisation remain separate checks. Contextual location overrides, descriptions and Google Photos remain committed work.
