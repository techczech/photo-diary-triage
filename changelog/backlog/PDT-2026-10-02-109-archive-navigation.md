---
item_id: PDT-2026-10-02-109
title: Responsive Archive keyboard navigation and reusable browse projections
status: shipped_pending_native_acceptance
target_release_version: 0.7.13
target_build: 149
target_feature_slug: archive-navigation
source: Original WP3 and mandatory keyboard/speed requirements; independent development authorisation
---

# Reliable Archive navigation

The continuing full-scope audit with Astra found that adaptive cards use a fixed four-column keyboard stride, title sorting differs from visible year groups, Back selects the first Walk instead of the child just viewed, and every arrow rebuilds the Map from all photos. Map keyboard actions also target invisible Trip entries. Correct these existing controls while preserving the approved year-grouped browsing design.

## Constraints and implementation intent

Use the same measured grid configuration for rendering and arrow movement. Move vertically between rendered rows, including short rows and year boundaries, and horizontally in visible order. Keep year groups newest first and title sorting within each year; the app currently offers Newest first and Title only. Retain the originating Walk/folder when navigating up. Make Map keyboard selection correspond to its visible Walk/folder list. Expose Back on the photo header and make Open act on a photo once inside a folder. Scope plain Return and arrows to the focused browse surface; add a focus request for Archive cards.

Cache catalogue/filter/search projections independently of selection, including counts, grouped ordering and Map computation. Rebuild them when the catalogue or actual query/filter/sort changes. Never hydrate originals or launch the native app during this work.

## Test conditions and success criteria

Add regressions before changing behaviour. Exercise one/two/four columns, exact width thresholds and narrow panes; title order across years; vertical movement through short rows and year boundaries; Walk selection and Back from a non-first Walk; historical folder and Map return destinations; visible Map selection/open order; Archive focus requests; photo Open; catalogue/filter/sort/query invalidation; and repeated actual AppState navigation over a large archive without rebuilding its photo-derived projections. Run the complete existing suite and verify the real signed bundle while closed. Native geometry, focus and keyboard acceptance remains explicit.

## Whole-scope remaining work

Separate follow-on implementation is required for visible photo search results and hit focus, successful empty/error/retry folder states, asynchronous bounded cover loading with zero reads when previews are hidden, and complete keyboard sidebar focus. Record these as unresolved implementation gaps in the master audit; they are not merely native acceptance gates. Real OneDrive, LM Studio, Google and copied historical/migration acceptance also remains required. Dominik has delegated routine implementation judgement and is away, so this spec proceeds under that existing authority.

## Result

Implemented in 0.7.13 build 149. Four tests reproduced existing defects before fixes.
All 401 tests pass, including 17 new navigation cases. Astra's follow-up findings were
corrected before its clear final source review. The real signed bundle was installed
while closed and verified against the build. Remaining WP3 implementation stays active.
