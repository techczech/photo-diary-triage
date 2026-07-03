# PDT-2026-07-03-097 Walkfolio 1.0 — the completion plan

item_id: PDT-2026-07-03-097
title: Walkfolio 1.0 — archive manager with a strong triage component, complete
status: approved_for_implementation
target_release_version: 1.0.0
target_feature_slug: walkfolio-1-0

## User request summary

Go back to the original plans and finish: no MVPs, no deferrals, one solid plan for
everything, one great final app. The staged/sliced approach stalls; this plan commits the
full remaining scope at once. Product identity shifts from "triage tool" to **photo archive
manager with a strong triage component**, named **Walkfolio** ("a photo walk diary & archive
manager for Mac"). Grilled and decided with the user on 2026-07-02/03; domain language in
[CONTEXT.md](../../CONTEXT.md), key decisions in
[docs/adr/0001](../../docs/adr/0001-archive-layout-trips-as-month-level-folders.md)
and [docs/adr/0002](../../docs/adr/0002-archive-index-derived-jsonl-in-pinned-folder.md).

## Domain model (settled — see CONTEXT.md)

- **Walk** = one photographic outing; may draw from several Sources (camera + phone);
  several per day possible. (Deliberately opinionated term; UI display label configurable.)
- **Trip** = named group of Walks, one story (holiday/journey); a physical month-level
  folder; the plain month folder is the default Trip. A Walk belongs to exactly one Trip.
- **Triage** = the act (and working state) of importing Walks from Sources and organising
  them into Trips. Historical processing is ordinary Triage on old folders.
- Layout (ADR 0001): `YYYY / MM-MonthName[-Trip-Slug] / DD-Ddd-Walk-Slug /
  YYYY-MM-DD-slug-NNN.ext`. Weekday token configurable (English default). Cross-month Trips
  keyed by start month (day-first missort accepted).

## Scope — work packages (ALL committed; none optional)

### WP0 Reconciliation & re-founding
- Rewrite PRD.md and DESIGN.md to the new identity and domain model (Trips/Walks/Triage,
  archive-manager framing); PRD "Non-Goals" no longer lists maps/LM Studio/historical.
- Rename app display name to **Walkfolio**, tagline "a photo walk diary & archive manager
  for Mac". Bundle id/repo slug unchanged. Walk/Trip display labels user-configurable in
  Settings (model + manifest terms stay canonical).
- Tracking cleanup: batch-normalize the 93 `awaiting_user_review` zombies (append
  `status_normalized` events — implicitly accepted by sustained use); close stale crop-repair
  items (-076, -079) superseded by the 0.2.44–0.2.48 crop rework; dead-path fixes (done
  2026-07-03).
- GATE: user tests 0.2.51 map render fix (item -096) before map work resumes.

### WP1 Domain model rework (code)
- Introduce Trip and Walk models; migrate the legacy `ImportSession`/walk-metadata concepts;
  Triage becomes the working-state concept (SessionKind/UI naming updated).
- Multi-source Triage (camera + phone in one sitting); day/time-cluster grouping proposes
  Walk boundaries; commit targets: new Trip (default: each Walk becomes its own single-Walk
  Trip named after itself) or an existing Trip.
- Archive layout v2 migration tool for the existing archive: dry-run report → folder
  renames/moves → manifest path rewrites → verification. Moving a Walk between Trips as a
  first-class operation (sibling folder move + manifest rewrite; OneDrive syncs moves as
  metadata, no re-upload).

### WP2 Archive Index & thumbnails (ADR 0002)
- Per-keeper ~512px thumbnails written at import; backfill for the whole existing archive.
- `_index/` folder: JSONL index sharded by year, one entry per photo/walk/trip; incremental
  rebuild on main machine after every import/edit; explicit full-rebuild command.
- Travel mode: never read archive photo bytes without explicit "Download to view";
  allocated-size≈0 heuristic for online-only detection (validate empirically once); browse/
  search/map run entirely from the index.

### WP3 Archive View
- Primary browse surface: **Timeline of Trips** (newest first; cover thumbnail, title,
  dates, location, counts) → Trip → Walks → photo grid. Folder drill-down UI retired
  (folders remain on disk).
- **Map mode**: every located Walk in the archive as a pin (clustered), click → open
  Walk/Trip. Index-backed, works without photo bytes.
- **Search**: filename + AI-description + titles/notes/locations/dates via SQLite FTS over
  the index. (Semantic search explicitly later — not in 1.0.)

### WP4 Locations (C.3 rework)
- Location (name + coordinate) lives on the Walk: pin-drop or GPS centroid.
- Optional overrides per time-cluster (dictated original: shared map reference for a
  proximity group) and per photo.
- Trip location derived from its Walks; overridable label only.
- Assignment is contextual (from a selected walk/cluster/photo), not a target-selector.

### WP5 AI descriptions (LM Studio)
- On-demand describe: photo, Walk summary, Trip overview. Never automatic during Triage
  (triage speed is non-negotiable). Batch queue for historical backfill ("describe
  everything in 2013").
- Output is an immutable machine fact: stored in manifests with model + date provenance,
  regenerable, never hand-edited, strictly separate from user notes. Purpose: search.
- Keepers only (only archived photos). LM Studio OpenAI-compatible endpoint + model choice
  in Settings.

### WP6 Google Photos push
- OAuth (`photoslibrary.appendonly` + app-created readonly); push a Trip or Photo Log as an
  album, original quality (purpose: phone + sharing + extra backup). One album per Trip.
- Membership recorded in manifests (badges, like Photo Log status); one-time manual marks
  for folders synced before the app existed (API cannot list non-app media since 2025-03-31).
- Upload verify + retry; quota surfaced, never silently downgraded.

### WP7 Historical processing (Archive Triage maturation)
- Open any old folder (all live in OneDrive/BigData) as a Source for ordinary Triage with
  historical defaults: keep-all stance (material is pre-culled), folder names/paths harvested
  as proposed Trip/Walk titles and date fallbacks, missing/wrong EXIF falls back to file
  dates / folder date hints.
- Same safety model as SSD: source untouched until explicit verification-gated Cleanup.
- Output: photos renamed into the standard file scheme, Walks/Trips created or appended,
  thumbnails + index updated, AI description backfill queueable.

## User feedback from 0.3.0 test (2026-07-03) — folded into work packages

- Map renders (closed -096) but "no way to give photos GPS" → confirms WP4 (Locations) as
  specified: pin-drop / assignment at walk, cluster, and photo level.
- Archive sidebar tree must be **keyboard navigable** → WP3 requirement (Timeline and any
  tree navigation get full keyboard support per DESIGN.md parity rule).
- Folder rows should show **images from subfolders, not folder icons**, with a Settings
  toggle to disable subfolder previews for speed → WP3 (Timeline covers + WP2 thumbnails
  deliver this; the speed toggle is a WP3 setting; travel mode uses index thumbnails only).
- Header row duplicated toolbar controls; mode tabs and Open in Finder belong at the top →
  fixed immediately in 0.3.1 (header cleanup; duplicate inspector/shortcut buttons removed).

## Explicitly OUT (decided, not deferred-by-default)

- Straighten / rotation (user: "crop is enough"); contrast/adjustment and all editing.
- Strava/Garmin GPX correlation ("just a thought, not essential").
- Semantic/embedding search (clean later add over stored descriptions).
- Aspect-ratio presets, ratings/labels, EXIF overlay, histogram, focus-AI, best-of-burst,
  batch edit, filmstrip (carried over from -090 exclusions).

## Constraints

- Triage speed, keyboard-driven operation, and grid primacy remain non-negotiable
  (AGENTS.md product priorities).
- Sources are never modified outside explicit Cleanup; manifests are canonical; the index
  and SQLite are derived and disposable; AI output always carries provenance.
- Travel machine never hydrates photo bytes implicitly (ADR 0002).
- Each work package ships as versioned releases with reports per changelog/AGENTS.md, but
  the SCOPE is committed as a whole — no package is dropped or deferred without a new
  user decision recorded here.

## Test conditions

- WP1: unit tests for layout v2 naming, migration dry-run on a copy of the real archive
  (zero data loss, manifest paths resolve); multi-source triage produces correct Walks.
- WP2: index round-trip (manifests → index → SQLite) lossless; travel-mode byte-read audit
  (no hydration on browse/search/map paths); thumbnail backfill count matches keeper count.
- WP3: timeline renders whole archive from index alone; FTS finds filename + description
  hits; map mode opens correct Walk.
- WP4: location round-trips to manifests; centroid vs pin precedence tested.
- WP5: description round-trips with provenance; regeneration replaces, never merges.
- WP6: album create + upload verified against a test Google account; membership marks
  persist in manifests.
- WP7: end-to-end historical run on one real old folder (e.g. a 2013 trip): keep-all,
  harvested names, correct Trip, verified copy, cleanup gated.
- End-to-end 1.0: SD card triage → Trips → described → located → searchable → visible on
  travel machine → pushed to Google Photos, without Finder and without MVP gaps.

## Success criteria

- The 2026-07-02/03 grilled decisions (CONTEXT.md + ADR 0001/0002) are fully implemented;
  nothing in "Scope" was quietly dropped.
- The user can run their entire photo life in the app: new-photo triage, 20-year historical
  ingestion, browse/search/map anywhere, Google Photos push — with the archive remaining a
  plain-text-legible folder tree.

## Status

Approved by user 2026-07-03 (scope + name: Walkfolio). Implementation starts with WP0.
Standing gate: 0.2.51 map-fix test (item -096).
