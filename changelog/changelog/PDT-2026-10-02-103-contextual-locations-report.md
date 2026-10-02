---
item_id: PDT-2026-10-02-103
title: Contextual Walk and selected-photo locations
shipped_release_version: 0.7.7
shipped_build: 143
shipped_feature_slug: contextual-locations
status: shipped_pending_native_check
---

# Walkfolio 0.7.7: assign locations without losing camera GPS

The inline Map targets the active canonical Archive Walk when no photos are selected, or exactly the selected original photos. A group receives one shared assignment identity and date; assigning one member again detaches only that member. Mixed groups start blank, selection changes reset the editor, and saves capture their target before asynchronous work. An unrelated loaded Photo Log cannot supply or receive the Archive location. Canonical Walk grids use stable indexed photo identities on both machine roles.

Photo overrides live in additive frontmatter. Existing latitude/longitude remain embedded GPS. Effective precedence is override, Walk pin, GPS; clearing restores fallback. Walk pins still control archive-wide Map placement, otherwise original effective points form a centroid with accurate provenance. Crop derivatives inherit their original and do not alter centroid weighting; unsupported crop/historical targets remain read-only.

A locked canonical transaction preflights every target, captures actual Walk/photo identities and original/replacement text, persists recovery first, then writes atomically. Retry retains the shared UUID and rejects conflicting text. Archive-relative recovery survives root relocation. Unfinished groups block overlapping moves/migration, index publication and metadata edits. New saves refuse unfinished imports or folder operations. Serialised save/index work and generation guards preserve the latest visible result.

## Files changed

ArchiveLocationEditor and LocationAssignmentContext implement canonical persistence, recovery, targeting and projection. Models/ManifestRenderer/ArchiveIndex/ArchiveCatalogue add optional override/raw-GPS/identity metadata. AppState, BrowserViewModel and MapPanelView expose contextual editing. Folder/migration and metadata services guard pending operations. ArchiveLocationTests supplies workflow regressions; README, release metadata and the development plan describe the current boundary.

## Verification

- **261 tests in two suites passed in 11.782 seconds**, versus 249 before this slice.
- Round-trip, clear fallback, raw-GPS/notes/unknown-field preservation, shared membership and individual reassignment pass.
- Interrupted batch, whole-batch compare-and-swap conflict, captured legacy identity, relocated recovery, retained index and resumed-move guards pass.
- Canonical Walk moves and index-only reconstruction preserve assignments and provenance.
- Actual Main and Travel AppState routes retain stable IDs, capture selected targets, update points and leave an unrelated loaded log intact. Travel writes no index and grants no original access.
- Crop inheritance/read-only selection and clear fallback pass. Native Map interactions were not exercised while the reviewer was away.
- Astra reviewed twice; four concrete findings and a scheduling failure were corrected and covered. Its second review found no further P1/P2 issue in the reviewed changes.
- Package/install signature, executable equality and version checks accompany the release; no live archive rebuild, migration, cleanup or photo hydration is part of this validation.

## Remaining goals

Travel writes update the current view and tiny canonical manifests; a main index rebuild/publication is needed for other index-only views, including after relaunch. New provenance values require 0.7.7 or later on machines sharing the index. The local lock is cooperative, not distributed across OneDrive machines.

Trip location-label override, historical defaults, LM Studio descriptions/provenance/batch and Google Photos delivery remain approved work. Development continues independently.
