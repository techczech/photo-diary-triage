# Walkfolio 0.7.3 folder thumbnail preparation

## Governing design

- `DESIGN.md`
- `CONTEXT.md`
- `docs/adr/0002-archive-index-derived-jsonl-in-pinned-folder.md`
- `docs/adr/0003-archive-browse-includes-unorganised-folders.md`
- `docs/adr/0004-folder-scoped-archive-thumbnail-preparation.md`
- `design/archive-0.7.0-mockup/`
- `changelog/backlog/PDT-2026-07-31-099-archive-thumbnail-cache-speed.md`

## Feature behaviour

An open Archive photo grid exposes **Prepare thumbnails for this folder…** in
its header and the Archive menu. Confirmation distinguishes thumbnails already
available from online-only originals that require one explicit download. The
running state shows determinate progress and cancellation.

Preparation operates only on the primary photos represented in the open grid.
It promotes existing application-cache images into 512-pixel Archive Index
JPEGs before reading originals. Missing originals are processed with bounded
work, a 15 GB free-space floor, and eviction after successful thumbnail output.

Ordinary grid browsing continues to avoid online-only original reads. Visible
grid cells must outrank queued off-screen work.

## Implementation order

1. Extend Archive Index thumbnail preparation with an explicit photo list,
   cached-thumbnail promotion, progress, cancellation, and bounded work.
2. Add the approved grid-header and Archive-menu controls with a native
   confirmation.
3. Limit initial Archive thumbnail scheduling to the estimated viewport and
   allow visible requests to overtake queued background requests.
4. Add focused tests for scope, cached-thumbnail promotion, cancellation,
   safety, and priority promotion.
5. Run the full build and test suite, package and install Walkfolio 0.7.3, then
   create the exact-version Dev Traffic Control request.

## Completion conditions

- The approved states are implemented without changing Archive navigation,
  selection, Timeline, Contact Sheet, or grid layout.
- Folder preparation can be cancelled safely and never leaves an original
  hydrated solely for thumbnail generation.
- Reopening a prepared folder resolves small thumbnails without original reads.
- Release metadata, backlog, changelog, bundle, installed app, and commit agree
  on version 0.7.3 and feature slug `archive-thumbnail-cache-speed`.
