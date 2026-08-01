# PDT-2026-07-31-099 Fast cached thumbnails for Archive folders

item_id: PDT-2026-07-31-099
title: Fast cached thumbnails for Archive folders
status: shipped_pending_user_test
target_release_version: 0.7.3
target_feature_slug: archive-thumbnail-cache-speed

## User request summary

Make Archive photo-grid thumbnails load quickly and reuse local caches instead
of making each visit feel like a fresh thumbnail-generation pass.

## Constraints

- Archive browsing must continue to avoid implicit downloads of online-only
  originals.
- Locally available thumbnails must persist across launches and folder visits.
- Visible photos must take priority over work for photos outside the viewport.
- Any operation that downloads an online-only original must be explicit,
  cancellable, bounded, and must evict originals that it hydrated solely to
  produce a thumbnail.
- Timeline, Contact Sheet, photo-grid layout, selection, and keyboard behaviour
  must remain unchanged unless a separate design is approved.

## Evidence

- Walkfolio already has a persistent local thumbnail cache containing about
  4,700 files and using about 579 MB.
- The inspected `2025/06` folder contains 652 JPEGs. Five are currently local
  and 647 are OneDrive online-only placeholders.
- The Archive currently contains no generated Archive Index thumbnails, so an
  online-only original has no small preview that Walkfolio can display safely.
- The cold path uses Quick Look with four concurrent jobs. Successful results
  are stored persistently, but the cache cannot be populated from absent photo
  bytes without obtaining either a provider thumbnail or the original once.

## Recommended design

Add an explicit **Prepare thumbnails for this folder…** action to an open
Archive photo grid. It should show the number already cached and the number
still needed, request confirmation before any online-only originals are
downloaded, process a small bounded number at a time, write 512-pixel JPEGs to
the Archive Index thumbnail store, evict originals downloaded by the operation,
and expose progress and cancellation. Later visits should use those small local
thumbnails immediately.

Keep the existing whole-Archive backfill command for deliberate maintenance,
but do not make it the ordinary answer to opening one historical folder.

## Implementation intent

Reuse the existing bounded Archive Index thumbnail generator and eviction
policy, but give it a folder-scoped input and progress totals. Prioritise the
current folder and avoid queueing all filtered photos as if they were already
on screen. Preserve the current application cache as a second local cache for
photos whose originals are already available.

## Test conditions

- A folder-scoped run generates thumbnails only for photos under that folder.
- Existing cached thumbnails are skipped without reading original bytes.
- Online-only originals are processed with bounded concurrency and evicted
  after a thumbnail is written.
- Cancellation stops scheduling new downloads and preserves completed
  thumbnails.
- Reopening the folder resolves generated thumbnails from cache without
  reading originals.
- Visible requests outrank queued off-screen requests.
- The complete Swift test suite passes.

## Success criteria

- A previously prepared folder fills its visible grid from small cached files
  without reading photo originals.
- The app clearly distinguishes the one-time preparation cost from subsequent
  fast browsing.
- Opening an unprepared folder never silently downloads hundreds of originals.
- The installed release has a recorded version, build, feature slug, and a
  short live verification request.

## Current status

Dominik approved the folder-scoped preparation design on 2026-08-01. Walkfolio
0.7.3 implements and installs the approved interaction: the open Archive photo
folder can be prepared explicitly, progress can be cancelled, completed
thumbnails persist in the Archive Index, and actual visible cells overtake
queued background thumbnail work. The release is waiting for a short check
against the real Archive.
