---
item_id: PDT-2026-10-02-110
title: Visible photo search and recoverable Archive folder loading
status: shipped_pending_native_acceptance
target_release_version: 0.7.14
target_build: 150
target_feature_slug: archive-search-and-folder-feedback
source: Original WP3 filename/description/title/notes/location search and reliable photo-grid workflow
---

# Search to the matching photo

The full-scope audit found photo search results stored but never displayed or opened, no
hit selection after a folder load, indefinite spinners for empty/failed folders and search
cache races across cancelled catalogue work. Implement the actual result-to-photo route
and explicit loading/empty/error/retry feedback. Preserve approved year-based archive
cards, the photo-grid destination and index-only Travel.

## Implementation and constraints

Display matching photos alongside related Trips/folders. Keep one explicit highlighted
search target for Open and contextual actions; final photo browsing remains a grid. Select
and scroll to the exact path after a guarded cache/fresh folder load, retaining query and
hit when returning to search. Never fall back to a different photo if the indexed hit is
missing. Preserve filters/crop grouping visibility and arbitrary historical folder years.

Bind requests to a unique identity, captured root/role/Pictures-root/context generation,
folder path and owned catalogue/search generation. Query changes clear stale actionable
results. Isolate each derived search database and publish it with its accepted catalogue;
old cancelled work cannot overwrite the active cache. Capture one validated index snapshot
for both catalogue and FTS. Rebuild FTS transactionally and reject incomplete query reads.

Folder state distinguishes loading, loaded-empty, failure with Retry and missing hit.
Cache and fresh loads share hit-selection guards. Back, filters, query replacement,
workspace/context changes and same-root backup restore invalidate incompatible pending
work and stale caches. Restore resets navigation even when its settings root is identical.
Do not launch the app, mutate the real archive or hydrate originals implicitly.

## Meaningful test conditions

Reproduce existing result-to-photo and historical-year/root-entry bugs before fixes.
Exercise actual SQLite/index-only Travel and Main historical paths, duplicate filenames,
RAW/crop families and review filters. Deliberately reverse suspended query/catalogue/folder
completions across roots, queries A/B/A, same and different folders, retry, Back/filter/
workspace changes, role change and same-root restore. Verify cached-hit selection, missing
hits, empty/error/retry states and selected-result return. Verify catalogue and FTS share
one snapshot; old isolated rebuilds cannot change accepted search results. Run the full
suite, Astra review and mechanical signed bundle checks. Native focus/layout and original
real-copy/OneDrive/LM Studio/Google acceptance remain explicit.

Asynchronous bounded covers and complete sidebar keyboard focus remain the next original
WP3 implementation work. They are not silently treated as native-only gates. Dominik has
authorised independent judgement and Astra consultation, so routine fixtures/code proceed.
