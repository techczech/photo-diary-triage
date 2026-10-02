---
item_id: PDT-2026-10-02-110
title: Visible photo search and recoverable Archive folder loading
status: shipped_pending_native_acceptance
release_version: 0.7.14
build: 150
feature_slug: archive-search-and-folder-feedback
---

# Search and folder recovery

Matching photos now appear alongside related Trips/folders. Keyboard selection, Open
and contextual actions share the visible highlighted target in Timeline, Contact Sheet
and Map. Historical years come from their containing entry; the root folder owns its
indexed photos without absorbing recognised Trips. Exact root-relative paths identify
hits across duplicate filenames and fresh historical UUIDs. Search opens the photo grid,
selects and scrolls to that photo, resets a hiding review filter and retains the query/hit
on Back. A missing hit is explicit; no unrelated photo is substituted. Results scroll to
the restored selection when their view is recreated.

Folder state distinguishes loading, loaded-empty, failure/Retry and missing hit. Cache
and fresh loads use the same path-resolution route. One-shot search focus clears after
success or definitive absence; failed loads retain it for Retry. Ordinary refresh maps
selection, anchor, Preview, Compare and Compare's saved return selection to new UUIDs
through paths. Closing Preview/Compare while refresh is suspended remains respected.
Catalogue revisions prevent stale cache reuse while retaining prior items for live UI
state remapping. Unrelated folder cache data is preserved.

Search requests have unique identities. Query changes clear old actionable results at
once. Every accepted catalogue owns an isolated disposable FTS database; task leases keep
its files until reads finish. Catalogue and FTS consume the same captured, validated index
rows. DROP/CREATE/inserts are inside one SQLite transaction; interrupted/corrupt reads
throw instead of returning partial matches. Search does not silently truncate after
5,000 matches. Trip-location lookup is linear in index/catalogue size.

Folder and catalogue publication check request generation, captured root/role/Pictures
root, byte-policy context and selected folder. Back/filter/query/workspace/root/role/
Pictures changes and same-root backup restoration reject obsolete work. Fresh root/role
reloads capture the new context after settings publication. No original byte grant is
implied by search or grid navigation.

Trip-label saves use the owned catalogue/FTS refresh. Context-bound saved labels for all
edited Trips survive Travel's stale shared index until an accepted index carries the
same canonical identity and override. The original authorised identity permits legacy
nil-to-canonical promotion but rejects conflicting nonnil identities. Clearing a label
removes stale FTS text. Travel still reads its index and never hydrates originals or
reads canonical manifests implicitly during catalogue refresh.

## Files and verification

New ArchiveSearch.swift supplies typed targets, folder states, containment and owned
FTS leases. ArchiveSearchResultsView.swift displays cards. AppState, ArchiveCatalogue,
ArchiveNavigation, ArchiveMapView, ArchiveBrowserViews, UIState, BrowserViewModel,
ContentViewBrowserSections and TripLocationEditor integrate publication and recovery.

ArchiveSearchWorkflowTests.swift adds 22 test functions, including parameterised
navigation/context/Map/legacy cases. Three original defects failed before fixes:
 /private/tmp/walkfolio-search-before.log
All 423 tests pass in 23.227 seconds (baseline 190):
 /private/tmp/walkfolio-search-full-final.log
Suspended handlers and captured real task handles force reversed query A/B/A, root and
folder completions; old errors cannot replace new success. Back/filter/query/workspace,
root/role/Pictures and same-root restore are covered. Actual SQLite rollback preserves
the old table after failed CREATE; corrupt/interrupted reads fail; 5,100 matches survive.
Cache/fresh/missing/empty/foreign/nil/retry, duplicate filenames, fresh UUIDs, Compare
close and saved return selection, cleared labels, two-Trip Travel saves/refresh and legacy
identity promotion pass. A fresh owned FTS/index-only Travel search-to-grid journey runs
with nonexistent originals and manifests. A final focused two-case check also verifies
both historical-folder and Archive-root exact-hit opening:
 /private/tmp/walkfolio-search-root-folder.log
Captured rows remain coherent even when the
current index has changed to corrupt text. Existing crop/import/backup/provider fixtures
remain green. Astra's final read-only source review found no remaining material issue;
it did not run tests or certify native/provider behaviour.

Real bundle built and signed:
 /private/tmp/walkfolio-search-bundle.log
Installed version/build: 0.7.14/150. Strict/deep codesign passed; installed executable
matches the signed package. Package matches compilation after stripping signing envelopes.
Release metadata matches APP_RELEASE.env. App remained closed. Previous real bundle:
 /private/tmp/Walkfolio-before-archive-search-0.7.14.app

## Remaining work

Asynchronous bounded cover reads and sidebar keyboard focus remain original WP3
implementation work. Native result layout, initial lazy-grid scroll timing, focus,
responsiveness and retry controls remain unverified. Original copied historical/migration,
OneDrive, LM Studio and Google test-account acceptance also remains required. No headed
launch, live archive or private-photo delivery ran. Version 1.0 is unaccepted.

The exact-version return request has four checks and a synthetic disposable archive;
no watcher runs. It is separate from the original whole-workflow acceptance conditions.
