# Archive 0.7.0 implementation plan

Status: authorised.
Release: `0.7.0`
Feature slug: `timeline-and-search`
Backlog item: `PDT-2026-07-12-098`

### Locked inputs

- UI: `design/archive-0.7.0-mockup/`
- Structure: `docs/adr/0003-archive-browse-includes-unorganised-folders.md`
- Release contract: Release D in `planning/codex-implementation-plan.md`
- Canonical terms: `CONTEXT.md`

### Data

- Add an `ArchiveCatalogue` derived from Archive Index JSONL shards and the physical
  Archive directory.
- Treat manifest-backed index rows as the only authority for Trip and Walk identity.
- Find maximal physical folders containing photos which are not covered by an indexed
  Trip or Walk. Emit rebuildable Unorganised Folder summaries.
- Never infer a month, Trip, or Walk from folder depth, folder spelling, or a year cut-off.
- Store searchable Archive Index rows in a disposable SQLite cache with FTS5.
- Keep Archive-relative paths as stable identifiers. Rebuild the cache when shards or the
  Archive root change.

### State

- Add a narrow `ArchiveBrowserState` and equatable snapshot.
- Persist Timeline or Contact Sheet choice and the photo-preview toggle in `AppSettings`.
- Preserve selected entry across view changes. Reconcile selection only when filters hide
  it.
- Model year and entry type as filters, not destinations.
- Model levels explicitly: Archive, Trip, and photo grid.

### UI

- Replace Archive mode's tree with Archive, Trips, Unorganised Folders, and year filters.
- Replace Archive mode's folder list with the locked Timeline or Contact Sheet.
- Keep view and sort controls beside the Archive title; keep search in the Archive toolbar.
- Show entry kind, cover, date or range, location or path, Walk count, and photo count.
- Trip open: show indexed Walk cards; Walk open: existing photo grid.
- Unorganised Folder open: existing photo grid, without writes or renames.
- `Organise as a Trip…`: explicitly open the folder as Triage source; do not mutate the
  folder until the existing copy workflow is confirmed.
- Provide visible empty and error states.
- Use Archive Index thumbnails only in Travel mode. Do not hydrate photo bytes on browse.

### Keyboard and commands

- Timeline: Up and Down select; Contact Sheet: all arrow keys select.
- Return opens. Escape moves from photo grid to Trip, or Trip to Archive.
- Add visible menu commands for Timeline, Contact Sheet, search focus, open, and preview
  toggle. Keep text-entry focus exempt from Archive navigation.

### Thumbnail safety

- Before backfill, check free space against the configured safety floor.
- Process one online-only file at a time: hydrate by explicit byte access, generate the
  index thumbnail, then evict through File Provider where available.
- Stop safely on cancellation or low free space. Record progress and failures.
- Existing thumbnails require no source-byte access.

### Tests

- Mixed hierarchy: indexed Trips plus irregular folders before and after 2016.
- No folder-depth or year-boundary classification.
- Folder summary count, date range, cover lookup, and maximal-folder rule.
- Index shard ingestion, rebuild detection, FTS filename and description queries.
- Timeline order, year/type filter, view persistence, and selection continuity.
- Trip to Walk to grid navigation; Unorganised Folder direct-to-grid without writes.
- Travel browse uses index thumbnails and performs no source-byte reads.
- Backfill low-space, cancellation, bounded processing, and eviction policy.
- Full `swift build` and `swift test`.

### Release completion

- Bump `APP_RELEASE.env` to `0.7.0` / `timeline-and-search`.
- Build the app bundle and verify embedded release metadata.
- Install the bundle when permission allows.
- Write the implementation report and append both JSONL logs.
- Commit with the required co-author trailer.
- Create one Dev Traffic Control test request for the exact installed version.
