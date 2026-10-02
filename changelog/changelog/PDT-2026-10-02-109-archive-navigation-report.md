---
item_id: PDT-2026-10-02-109
title: Measured Archive navigation and reusable catalogue projections
status: shipped_pending_native_acceptance
release_version: 0.7.13
build: 149
feature_slug: archive-navigation
---

# Archive navigation

Archive and Walk cards render explicit columns from measured pane width; arrows use the
same configuration. Navigation follows displayed year groups and restarts rows at year
headers. Short rows preserve the intended vertical column. Clicks, resizing, view changes
and entering another grid reset it. Title sort stays within newest-first year groups.

Back retains the Walk or historical folder just opened, including Map entry points.
The photo header exposes Back; Open previews the focused photo. Focus Review works on
Archive cards without loaded photos. Card clicks reacquire keyboard focus after editing.
Plain Return is scoped to the focused card surface; its global menu shortcut was removed.

Map highlights and scrolls keyboard selection in visible order: located Walks, unlocated
Walks and historical folders. Open and contextual actions resolve that selection.
Selected-material description targets the Walk, Trip actions its parent, and Organise
and manual Google marks the highlighted folder. Old selection cannot target unrelated
material.

Catalogue counts, year groups, entry order, photo matches and Map are cached independently
of selection. Catalogue, filters, sorting, query/matching paths and archive context
invalidate the cache. Photo matches respect entry-kind filters. Selection does not
regroup every archive photo or recompute GPS.

## Files and verification

ArchiveNavigation.swift contains shared geometry/navigation/projection. AppState, UIState
and ArchiveBrowserViews integrate it; ArchiveMapView shows selection; AppCommands scopes
Return; ContentViewBrowserSections exposes Back.

ArchiveNavigationTests.swift adds 17 regressions. Four reproduced current defects before
implementation. Coverage includes widths/resizing, short rows/year boundaries, title order,
grid reset, actual Back/Open and historical Organise, Map action ownership, cached query/
filter/catalogue/root invalidation and focus requests. Actual AppState over 50,000 photos
and 100 Walks reuses its projection across 1,000 arrow calls; filters rebuild and clearing
them restores the correct Map.

All 401 tests pass in 19.163 seconds, baseline 190. Full output:
 /private/tmp/walkfolio-navigation-full.log
Pre-fix evidence:
 /private/tmp/walkfolio-navigation-before.log
Astra found column carryover, stale Map action ownership and missing click focus.
All were corrected before its clear final source review.

Real bundle built; strict/deep codesign passed; installed executable equals build.
Installed version/build: 0.7.13/149. App remained closed. Previous real bundle:
 /private/tmp/Walkfolio-before-archive-navigation-0.7.13.app

## Remaining work

Native focus, rendered geometry and realistic responsiveness remain unverified; projection
reuse is not a native timing result. Visible photo search/hit focus, empty/error/retry
feedback, asynchronous covers and keyboard sidebar focus remain implementation gaps.
Real-copy historical/migration, OneDrive, LM Studio and Google test-account acceptance
also remains required. No headed launch, live archive or private-photo delivery ran.
Version 1.0 is unaccepted. The exact-version navigation request has no watcher.
