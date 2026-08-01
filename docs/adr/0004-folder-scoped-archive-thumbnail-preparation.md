# Folder-scoped Archive thumbnail preparation

An open Archive photo grid provides an explicit **Prepare thumbnails for this
folder…** action. The action reports how many photos are already cached and how
many online-only originals require a one-time download. Preparation writes
512-pixel JPEGs to the pinned Archive Index thumbnail store and evicts every
original hydrated only by the operation.

The action lives in the existing photo-grid header and Archive menu. A native
confirmation appears before online-only originals are read. While preparation
runs, the header shows determinate progress and a visible Cancel action.
Completed thumbnails remain valid when preparation is cancelled.

## Considered options

- **Download thumbnails automatically when a folder opens** was rejected
  because browsing must never silently hydrate hundreds of OneDrive originals.
- **Use only the whole-Archive backfill command** was rejected because preparing
  twenty years of photos is disproportionate when the user wants to browse one
  historical folder.
- **Use only the application cache** was rejected because the pinned Archive
  Index thumbnails provide the durable small-preview layer shared across the
  main and travel machines.

## Consequences

- The operation uses the primary photos already shown by the grid and does not
  generate duplicate thumbnails for RAW companions.
- Existing application-cache thumbnails are promoted into the Archive Index
  without reading their originals.
- Missing thumbnails are prepared with bounded work and the existing 15 GB
  free-space floor.
- Ordinary folder opening remains read-only and does not download originals.
- The visual design inherits the locked Archive mockup in
  `design/archive-0.7.0-mockup/`; this decision adds states to its existing grid
  header rather than changing the Archive layout.

Approved by Dominik on 2026-08-01.
