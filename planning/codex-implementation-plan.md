# Codex Implementation Plan — Walkfolio 1.0 (WP1.b → 1.0.0)

Audience: an autonomous coding agent (Codex) finishing the approved completion plan
[PDT-2026-07-03-097](../changelog/backlog/PDT-2026-07-03-097-photo-diary-completion-plan.md).
Work through the releases below IN ORDER. Do not skip, merge, or descope anything — scope
changes require an explicit user decision recorded in the -097 spec ("no MVPs, no
deferrals" is a standing user instruction).

## Read these first (mandatory)

1. `AGENTS.md` (repo root) — non-negotiable rules and product priorities.
2. `changelog/AGENTS.md` — tracking workflow. EVERY release needs: a report in
   `changelog/changelog/`, JSONL appends to `changelog/changelog.jsonl` and
   `changelog/backlog.jsonl` (item_id PDT-2026-07-03-097, events like
   `wp2_implemented` / status `wp2_shipped_pending_user_test`), and an `APP_RELEASE.env`
   bump. Every handoff must name the exact APP_VERSION and ask the user to test it.
3. `CONTEXT.md` — canonical domain language (Walk, Trip, Triage, Archive Index, AI
   Description, Photo Log, Location). Use these terms in code, manifests, UI, and specs.
   Walk/Trip UI display labels must become user-configurable; model/manifest terms stay
   canonical.
4. `docs/adr/0001` (layout v2) and `docs/adr/0002` (Archive Index) — settled decisions.
5. `DESIGN.md` — UX contract. Grid-first, keyboard/UI parity, closable modals, review-focus
   scoping for single-letter shortcuts. Design-affecting ambiguity → STOP and ask the user.
6. `PRD.md` — product framing.

## Environment and conventions

- Swift Package Manager app; build with `swift build`; bundle+install with
  `./scripts/build_app_bundle.sh` then `cp -R dist/Walkfolio.app /Applications/`.
- Tests: `swift test --filter <Suite>` per-suite. KNOWN PRE-EXISTING failures in the full
  suite (fix them in Release A below): a crop-nudge expectation in
  `ReviewInteractionTests.swift:33` and a fatal error ("Not enough bits to represent the
  passed value") aborting the run.
- Swift 5 language mode; Swift-6 Sendable warnings exist and are tolerated.
- PERFORMANCE PATTERN (do not regress): hot views observe narrow state objects
  (`SidebarState`, `ReviewState`, … in `UIState.swift`) with Equatable snapshots — never
  make grid/review views observe `AppState` wholesale. There is a history of perf
  regressions from SwiftUI invalidation (see PDT-2026-03-26-019…022).
- Admin/one-shot tools may use direct `NSAlert` (see
  `AppState.migrateArchiveLayoutInteractively` for the pattern).
- Git: new commits (never amend), never `--no-verify`, never force-push; end commit
  messages with the agent's Co-Authored-By trailer. Do NOT push unless the user asks.
- The user is the only tester. After each release: build, install to /Applications, write
  the report + JSONL, commit, then STOP and hand off with test instructions.

## Architecture facts you would otherwise have to rediscover

- Layout v2 (shipped 0.4.0): `YYYY / MM-MonthName[-Trip-Slug] / DD-Ddd-Walk-Slug /
  yyyy-MM-dd-slug-NNN.ext`. Name builders: `DateFormatting.archiveTripFolderName /
  archiveWalkFolderName / archiveFileStem` (`Utilities.swift`). Weekday token:
  `DateFormatting.weekdayFormat` ("EEE"), needs a Settings UI (Release B).
- `ArchiveLayoutMigrator.swift` migrates legacy app-written folders; pre-app folders (e.g.
  `2020/03/28`) are skipped — they enter via historical Triage (Release H).
- One-session-one-walk-folder is still baked into `ArchivePlanner.plan` (single
  `archiveFolder` from min capture date), `ImportCoordinator.commit` (one walk .md + one
  session log named after the folder), `ArchiveCommitPlan` (single URL). Release B breaks
  this.
- Manifest path fields: absolute `archive_path` + `archive_relative_path` relative to
  `session.oneDrivePicturesRoot` (NOT `archiveRoot` — they can diverge). Resolver:
  `ArchiveRelativePathResolver`.
- Browser: `BrowserViewModel.buildArchiveYearNodes/MonthNodes/WalkNodes` — years matched by
  `^(19|20)\d\d$`, month/walk names treated as opaque; media loads only at
  `.archiveWalkFolder` depth via `FileScanner.scanFolder`.
- `SessionKind` (`inbox`/`walkDraft`, displayed "Photo Log") gates workflow all over
  `AppState`. `WorkspaceMode`: archiveView / cameraTriage / photoLogs / archiveTriage.
- Thumbnails currently go to an app-support cache (`PreviewStore`,
  `QLThumbnailGenerator`), keyed by MD5 of path — Release C adds durable archive-side
  thumbnails, which is a separate artefact.
- Crop writes versioned outputs + `<basename>.crops.json` NEXT TO the source file
  (`CropService.swift`); crops of archived photos live inside walk folders.
- GPS: `MediaMetadata.latitude/longitude`, `MediaItem.coordinate`; map panel exists
  (`MapPanelView.swift`, macOS 14 SwiftUI Map) as an inline review panel with walk-level
  pin assignment (`walkMetadata.latitude/longitude`).

## Releases

### Release A — 0.4.1 `test-suite-repair`
Fix the pre-existing test failures so the full suite is green and stays the regression net
for everything below.
- `ReviewInteractionTests.swift:33` crop-nudge expectation: decide whether the test or the
  nudge math is wrong (read PDT-2026-05-29-092…095 crop rework reports before changing
  behavior; if behavior is correct, fix the expectation).
- Find and fix the fatal error ("Not enough bits to represent the passed value") that
  aborts the suite — likely an Int conversion overflow in a test fixture or date math.
- Acceptance: `swift test` completes with 0 failures.

### Release B — 0.5.0 `walk-trip-model` (WP1.b, the pivotal one)
Introduce Walks and Trips as real model objects and break one-session-one-folder.
1. Models (`Models.swift`): `Walk` (id, title, date, walk folder relative path, source
   provenance, location fields) and `Trip` (id, title or nil for default month Trips,
   start month key, member walk folder paths). A Triage (the working state, today
   `ImportSession`) holds proposed Walks.
2. Walk-boundary proposals: reuse `GroupingService` day/time-cluster output to propose
   Walk splits of the selected items at commit time; UI to confirm/merge/split and name
   each Walk (grid-first, keyboard reachable; sheet must be closable).
3. Commit targets: per Walk, default = its own new single-Walk Trip (month folder);
   alternative = choose an existing Trip (scan year folders for `MM-MonthName-*` named
   Trips + option to create a new named Trip). `ArchivePlanner` becomes per-Walk (one
   commit plan per Walk); `ImportCoordinator` writes one walk manifest + session log per
   Walk folder, plus a Trip manifest (`<TripFolderName>.md`) in named Trip folders
   recording title/dates/member walks.
4. Multi-source Triage: allow adding a second Source folder to an open Triage
   (`AppState.pickSourceFolder` gains "Add Source"); scanner results merge with provenance
   kept per item. Bursts/clusters computed across the merged set.
5. Walk moves: context menu on an archive walk node — "Move to Trip…" (picker of existing
   Trips in that year + "New Trip…"); implement as sibling folder move + sidecar path
   rewrite (reuse the migrator's rewrite logic; extract a shared helper), then refresh the
   browser and caches.
6. Settings: weekday token style (En abbreviations default) and Walk/Trip display labels
   (strings used in UI copy; "walk"/"trip" defaults).
7. Rename the legacy working-state naming user-visibly: UI strings that said
   "session"/"walk draft" for the working state say "Triage". (Code type renames may be
   incremental; `SessionKind.walkDraft` display name is already "Photo Log" — check with
   the user before changing Photo Log semantics.)
- Tests: boundary proposal math; per-Walk planner output (folders, stems); Trip manifest
  round-trip; walk-move path rewrites.
- MANUAL ASK: import a card with photos from ≥2 days; verify split proposal, one commit
  per Walk, and a named-Trip commit.

### Release C — 0.6.0 `archive-index` (WP2, ADR 0002)
1. Thumbnails: at import, write ~512px JPEG per keeper to `<archiveRoot>/_index/thumbs/
   <year>/<file-stem>.jpg`. Backfill command (File menu, NSAlert pattern) walks the
   archive and generates missing thumbnails (QLThumbnailGenerator; throttle; progress in
   status message).
2. Index: `<archiveRoot>/_index/index-<year>.jsonl` — one JSON line per photo, walk, and
   trip (paths relative to archive root, dates, titles, locations, EXIF summary, AI
   description placeholder, thumbnail path). Incremental update after every import /
   metadata edit / walk move; full "Rebuild Archive Index" command. Index is derived and
   read-only: on disagreement manifests win (rebuild fixes).
3. Travel guard: `ArchiveByteReadPolicy` — before any archive photo byte-read
   (`PreviewStore`, `DecodedImagePipeline`, `CropService`), check
   `totalFileAllocatedSizeKey ≈ 0 && fileSize > 0` → treat as online-only. In travel mode
   (`archiveMachineRole == .travel`), never read bytes for online-only archive items; show
   the `_index` thumbnail + a "Download to view" action that reads bytes explicitly.
   Validate the heuristic once against a real OneDrive online-only file and record the
   result in the release report.
- Tests: index round-trip (write walk folder → index entries match manifests); heuristic
  unit test with a sparse file; thumbnail naming.
- MANUAL ASK: rebuild index on the real archive; check `_index/` contents; on the travel
  machine (later) verify no hydration on browse.

### Release D — 0.7.0 `timeline-and-search` (WP3)
1. Timeline of Trips: Archive View's primary surface becomes a scrollable newest-first
   list/grid of Trip cards (cover thumbnail from `_index`, title, date range, location,
   walk/photo counts) → click → Trip page (its Walks as cards) → Walk → photo grid
   (existing). Data comes from the Archive Index (SQLite cache built from JSONL shards at
   launch/refresh). The old year/month drill-down UI is retired.
2. Keyboard navigation: full arrow/Enter/Escape traversal of Timeline → Trip → Walk →
   grid (user feedback 2026-07-03; DESIGN.md parity rule).
3. Subfolder previews: Trip/Walk cards show real image covers; Settings toggle "Show
   photo previews in browser" for speed (off = icon + counts only). Travel mode uses
   `_index` thumbs only.
4. Search: SQLite FTS5 over index content — file names, AI descriptions, titles, notes,
   locations, camera. Search field in Archive View toolbar; results as a photo grid;
   Enter on a result jumps to its Walk. Filename + description search minimum (user
   decision); semantic search is OUT for 1.0.
- Tests: index→SQLite ingestion; FTS query returns expected stems; timeline ordering.
- MANUAL ASK: browse the real archive by timeline; search a known filename and a word
  from a note.

### Release E — 0.8.0 `locations` (WP4)
1. Walk location: name + coordinate on the Walk (extend walk manifest + index). Derive
   from GPS centroid when photos have GPS; else pin-drop on the existing map panel
   (extends the C.2 walk assignment; same MapPanelView).
2. Overrides: assign a location to a selected time-cluster or selected photos
   (contextual action from the selection, not a target dropdown — user decision).
   Persist per-photo overrides in per-file manifests (`location_name`, `latitude`,
   `longitude` fields) and the index.
3. Trip location: derived label from member Walks (most common name or "A + B");
   user-overridable label in Trip manifest.
4. Archive-wide Map mode: a Map toggle in Archive View plotting every located Walk from
   the index (clustered pins; macOS 14 Map clustering or manual grid clustering); click
   pin → open that Walk. Must work purely from the index (no photo bytes).
- Tests: centroid math; manifest round-trip of all location fields; index carries
  locations.
- MANUAL ASK: assign a location by pin; verify a GPS walk auto-derives; open Map mode
  over the whole archive.

### Release F — 0.9.0 `ai-descriptions` (WP5)
1. Settings: LM Studio endpoint (default `http://localhost:1234/v1`) + model name +
   "test connection" button. Uses OpenAI-compatible `/chat/completions` with base64
   image content (LM Studio vision models).
2. On-demand actions: "Describe photo" (selected photos), "Summarise Walk", "Summarise
   Trip" — context menu + Triage menu. NEVER automatic during triage (speed rule).
3. Storage: per-file manifest gains an AI description block (`ai_description`,
   `ai_description_model`, `ai_description_generated_at`); walk/trip manifests get
   equivalent summary fields. Regeneration REPLACES (never merges); the user's own
   notes/title fields are never touched. Update the index on write.
4. Batch queue: "Describe all photos in <Walk/Trip/year>…" — serial background queue,
   progress in status bar, cancellable, resumable (skip items that already have a
   description from the same model unless "regenerate" chosen).
5. Search integration: descriptions land in FTS automatically via the index.
- Tests: manifest round-trip with provenance; queue skip/regenerate logic; endpoint
  client against a stubbed URLProtocol.
- MANUAL ASK: user must have LM Studio running with a vision model; describe one walk,
  search a word from a generated description.

### Release G — 0.10.0 `google-photos` (WP6)
1. OAuth: Google Photos `photoslibrary.appendonly` + `photoslibrary.readonly.appcreateddata`
   scopes; loopback OAuth flow (ASWebAuthenticationSession); client credentials supplied
   by the user in Settings — ASK THE USER to create the Google Cloud OAuth client (do not
   embed secrets in the repo; store token in Keychain).
2. Push: "Push to Google Photos" on a Trip or Photo Log — creates an app album named after
   the Trip, uploads originals (bytes upload → batchCreate with album), verifies each item
   (mediaItem id recorded), retries transient failures; quota errors surfaced plainly.
3. Membership: `google_photos_album`/`google_photos_uploaded_at` in walk/trip manifests +
   per-file media item ids; badges in Timeline/Trip views ("in Google Photos"). Manual
   one-time marking action for pre-app uploads ("Mark as already in Google Photos").
   The API cannot list non-app media (post-2025-03 restriction) — membership of manual
   uploads is declared, not discovered.
- Tests: upload client against stubbed URLProtocol (upload → batchCreate → verify);
  manifest round-trip of membership fields.
- MANUAL ASK: user provides OAuth client + runs one real push of a small Trip.

### Release H — 0.11.0 `historical-triage` (WP7)
1. Archive Triage mode matures into historical processing: open ANY folder (e.g. the
   pre-app `2020/03/28` folders or a 2013 holiday dump) as a Source with historical
   defaults: keep-all stance (all items pre-marked selected), Trip/Walk titles proposed
   from folder names/path segments, date fallbacks from folder-name hints then file
   mtimes when EXIF is missing.
2. Same safety model as SSD triage: source untouched; verification-gated Cleanup can
   remove the old folder's imported files afterwards (explicit, per-folder).
3. Commit uses the Release B per-Walk pipeline (splits, named Trips), writing v2 layout +
   thumbnails + index + (optionally queued) AI descriptions.
4. Dedup guard: `ArchiveCopySurveyor` runs by default in historical mode so re-processing
   an already-imported folder flags copies instead of duplicating.
- Tests: folder-name harvesting (dates/titles from real-world patterns:
  `2013-06 Croatia`, `2020/03/28`, `IMG_...` dumps); keep-all default; EXIF-less date
  fallback.
- MANUAL ASK: user processes one real historical folder end-to-end, including cleanup.

### Release I — 1.0.0 `walkfolio-1-0`
- Sweep the -097 spec top to bottom; anything unimplemented is a STOP-and-ask.
- End-to-end verification per the spec's "Test conditions": SD triage → Trips → described
  → located → searchable → travel view → Google Photos, no Finder.
- Close out: update README.md (Walkfolio identity, tagline, feature overview, install),
  final report, JSONL events, mark -097 pending the user's final approval.

## Standing rules while working

- One release per handoff; wait for the user's test result before the next.
- If code/design ambiguity touches DESIGN.md territory (interaction, layout, shortcuts,
  modality) — ask, don't assume (DESIGN.md Change Control).
- Update `CONTEXT.md` only if the user coins/changes a term; update ADRs only with the
  user; never let backlog/changelog drift from code.
- If you find contradictions between this plan, the spec, and the code — surface them in
  the handoff instead of silently resolving.
