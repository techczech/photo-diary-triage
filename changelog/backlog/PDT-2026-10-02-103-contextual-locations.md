---
item_id: PDT-2026-10-02-103
title: Contextual Walk and selected-photo locations
status: shipped_pending_native_check
target_release_version: 0.7.7
target_build: 143
target_feature_slug: contextual-locations
---

# Contextual locations

The approved completion plan requires manual photo and shared-cluster assignments without losing camera GPS. The existing inline Map uses the current context: a canonical Archive Walk with no photos selected targets its Walk pin; selecting original photos targets exactly those photos, with one shared assignment identity for a group. No target selector is added. Mixed selections start blank, and selection changes resynchronise the editor. Historical folders and synthetic crops lacking canonical photo manifests stay read-only.

Canonical photo frontmatter gains optional location override name, complete coordinate pair, assignment UUID and assignment date. Existing latitude/longitude retain embedded GPS. Effective precedence is photo override, then Walk pin, then embedded GPS. Clearing restores that fallback. Archive-wide Walk pins retain precedence; otherwise centroids use original effective photo points, excluding derivatives and identifying manual provenance.

Save through a locked, recoverable canonical transaction. Capture stable Walk/photo identity and archive-relative targets before writing; preflight every target; retain exact old/new text; persist the operation first; resume only original or already-written text. Preserve human notes and unknown fields. Incomplete location operations block overlapping moves and migrations. Travel edits write only targeted tiny manifests and recovery, update the current view, and never grant original-byte access or write the main index.

Tests cover round-trip and clearing, invalid pairs, shared membership and reassignment, failure between writes, compare-and-swap conflicts, move/rebuild/relocation preservation, index-only reconstruction, contextual AppState targeting with an unrelated loaded Photo Log, and read-only historical/crop targets. Native Map interaction remains a separate optional check. The approved Trip location-label override remains explicitly outstanding after this slice.

## Implementation checkpoint

Canonical Archive Walk maps target no-selection Walk pins or captured selected originals. Stable indexed identities are used on both Main and Travel machines. Mixed assignment state starts blank; location context lookups are cached. Raw GPS and notes survive edits, clears, moves and reconstruction. Shared assignments carry a UUID/date; crops inherit their original's point and stay read-only. Saves and index refresh are serialised, stale catalogue/media loads cannot undo visible points, and unfinished location operations block index publication and overlapping moves, migration, imports or other metadata edits.

Full suite: 261 tests in two suites passed in 11.782 seconds. Astra's findings became regressions; its second review found no further P1/P2 issue. Native Map interaction remains unverified. Trip label overrides remain an explicit approved follow-up. Travel changes are visible immediately in the current view and canonical tiny manifests; other index-only views await main index publication.
