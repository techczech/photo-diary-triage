---
item_id: PDT-2026-10-02-105
title: Canonical Trip location label overrides
status: shipped_pending_native_check
target_release_version: 0.7.9
target_build: 145
target_feature_slug: trip-location-labels
---

# Trip location labels

Approved completion scope: a Trip location is derived from its Walks and permits a label-only override. Expose the override in the recognised Trip view, preserve its absence versus a manual label, and clear to the current derived fallback without changing any Walk/photo coordinates.

Store an additive owned header field in canonical Trip Markdown. Default-month Trips need a stable canonical identity and member list just as named Trips do; create/update those records through imports and moves, and discover existing canonical Walk members when creating the first Trip record. Unknown fields, notes, member ordering/identity and public title must survive edits and reconstruction. Never infer a Trip from arbitrary historical folder depth.

Canonical saves capture the path/identity/expected override, refuse stale/conflicting identity or labels, check path containment/symlinks and unfinished overlapping operations, and replace one manifest atomically. Rebuild and partial index updates read current canonical labels. Index-only Travel browsing still reads only pinned records; targeted tiny-manifest editing does not grant original-byte access or write its index. The current view may reflect the save; main index publication supplies future index-only views.

Acceptance tests cover default/named Trips, quotes/non-English labels, clear/fallback, notes/unknown-field preservation, append/move membership, conflict/failure safety, relocated reconstruction, explicit historical refusal, actual AppState target capture and Travel index/byte policy. Native controls remain separately reviewable. Descriptions and album delivery are the next completion slices.
