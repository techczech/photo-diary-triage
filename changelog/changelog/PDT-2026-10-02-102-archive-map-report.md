---
item_id: PDT-2026-10-02-102
title: Archive-wide Map and explicit travel viewing
shipped_release_version: 0.7.6
shipped_build: 142
shipped_feature_slug: archive-map
status: shipped_pending_native_check
---

# Walkfolio 0.7.6: locate archived Walks and view originals deliberately

Archive Map uses the same year, type and search filters as Timeline and Contact Sheet. Every located Walk has an index-backed pin; MapKit clusters nearby pins, a cluster zooms into its members, and a Walk opens its existing photo grid. The adjacent list includes located/unlocated Walks and historical folders. Map state is independent of the open Photo Log.

Saved Walk pins override original-photo GPS centroids. Coordinates are validated as complete finite pairs, including import/index fallback; they are never spliced from separate sources. Spherical centroids handle the antimeridian and reject ambiguous antipodal sets. Crop derivatives are excluded from weighting. New index rows retain provenance; older unknown provenance is not relabelled as GPS.

Travel originals now require explicit Download to view even when local, matching the approved archive contract. The action materialises one selected path and opens Walkfolio's preview. It does not launch another app. In-memory grants are revoked by archive policy changes; neighbouring preheat and implicit thumbnail generation remain blocked. FileProvider callbacks are cancellable and the whole request/readiness operation has a deadline. Late transport/decode results cannot grant or return an unconsented original. Prepared index thumbnails remain usable. Archive cover and EXIF paths have corresponding byte guards.

## Verification

- **249 tests in two suites passed in 11.711 seconds**, up from 235 in the travel release.
- A fresh root containing only _index reconstructs located Walks, opens the actual AppState archive route and loads stable photo IDs without originals. Year/search/type projection and unknown-location coverage are tested.
- Tests cover pin precedence, invalid/partial pairs, antimeridian/antipodal centroids, crop weighting and legacy provenance.
- Tests cover resident consent without transport, timeout/error/cancellation, uncooperative stalled transport, late completion after policy reset, path escape, in-app viewing and revoked in-flight image decode.
- The build compiles the native MapKit clustering view. Astra independently reviewed projection, navigation, byte consent, provider timeout and decode revocation; findings became regressions.
- The real 0.7.6 build 142 is packaged and locally signed. Installed version/build, executable equality and strict deep signature verification are checked without launching the interface.

## Limits and remaining goals

Native clustering/click behaviour and real OneDrive hydration are not established by compiler or fixture tests. No live archive bytes were hydrated for this work and no real archive was migrated, rebuilt or cleaned. A native check is recorded separately for the reviewer's return, without an answer watcher.

Per-photo/cluster contextual override editing, historical metadata defaults, LM Studio descriptions/provenance/queue and Google Photos delivery remain unfinished parts of the approved scope. Development continues independently.
