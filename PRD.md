# Walkfolio PRD

Walkfolio — a photo walk diary & archive manager for Mac.

This PRD is subordinate to [DESIGN.md](./DESIGN.md) for UX, interaction, shortcut, layout,
popup, persistence, and launch-model decisions. Domain language is defined in
[CONTEXT.md](./CONTEXT.md); structural decisions live in [docs/adr/](./docs/adr/). The
committed 1.0 scope is
[PDT-2026-07-03-097](./changelog/backlog/PDT-2026-07-03-097-photo-diary-completion-plan.md).

## Product Summary

Walkfolio is a local-only macOS photo archive manager with a strong triage component. It
manages a multi-decade photo diary — the Archive — organised into Trips made of Walks, with
durable Markdown/JSONL manifests beside the photos so nothing important is ever trapped in a
database. New photos enter through fast, keyboard-driven Triage from an SSD or any folder;
old photo folders enter through the same Triage applied historically. The Archive is
browsable as a timeline, on a map, and through search (filenames + local-AI descriptions),
on any machine — including a travel laptop that holds only the text index, never the photo
bytes.

## Problem

- A 20-year photo collection is scattered across ad hoc folders with no consistent
  structure, descriptions, or locations.
- Importing everything before choosing creates duplicate storage; deleting inside import
  flows is risky.
- Metadata trapped in proprietary databases dies with the tool that made it.
- Finding anything ("that bridge in Croatia") requires remembering where it lives.
- On a travel machine, browsing a cloud-synced archive silently downloads gigabytes.

## Goals

- Triage directly from a Source (SSD, phone folder, old archive folder) without modifying it
  until explicit verification-gated Cleanup.
- Organise the Archive as Trips (month-level folders; the plain month is the default Trip)
  containing Walks (one photographic outing each) — ADR 0001.
- Keep manifests canonical: Markdown/JSONL beside the photos; SQLite and the Archive Index
  are derived and disposable — ADR 0002.
- Browse the whole Archive as a Timeline of Trips, a map of located Walks, and full-text
  search over filenames, AI descriptions, titles, notes, and locations.
- Describe archived photos, Walks, and Trips on demand with a local LM Studio model;
  descriptions are provenance-stamped machine facts that serve search.
- Assign Locations (name + coordinate) to Walks, with time-cluster and per-photo overrides.
- Push Trips or Photo Logs to Google Photos (original quality, album per Trip) and track
  membership.
- Process historical folders with the same Triage (keep-all default, folder-name
  harvesting), building the complete diary.
- Work correctly on a travel machine: browse/search/map from the pinned `_index/` alone;
  never hydrate OneDrive photo bytes without an explicit request.
- Preserve fast working state in SQLite while exporting durable text records; persist
  settings and session memory; support manual backup export/import.

## Non-Goals

- Photo editing: no straighten/rotation, contrast, color, or adjustments (crop exists as a
  non-destructive triage aid and is complete).
- Strava/Garmin GPX correlation.
- Semantic/embedding search (a later addition over the stored descriptions).
- Cloud sync of photos by the app itself (OneDrive handles bytes; the app manages awareness).
- Multi-user collaboration.

## Primary User

A single photographer maintaining a decades-long photo diary: returning from walks with an
SSD of new photos, carrying a travel laptop with an online-only OneDrive archive, and
sitting on 20 years of pre-culled historical folders that deserve the same structure,
descriptions, and findability.

## Core Concepts

See CONTEXT.md for the full glossary. The load-bearing terms:

- **Walk** — one photographic outing, possibly from several Sources (camera + phone).
- **Trip** — a named group of Walks (one story); a month-level folder; the plain month is
  the default Trip. Every Walk belongs to exactly one Trip.
- **Triage** — the act (and persisted working state) of importing Walks from Sources and
  organising them into Trips.
- **Archive Index** — derived year-sharded JSONL + thumbnails in one pinned `_index/`
  folder; the travel machine's whole view of the Archive.
- **AI Description** — regenerable, provenance-stamped, never hand-edited; exists for
  search.
- Walk/Trip UI display labels are user-configurable; model and manifest terms are canonical.

## Core Workflows

### New photos (Triage)
1. Open a Source (or several: camera + phone) — scan, extract metadata, group by burst and
   time cluster.
2. Grouping proposes Walk boundaries; review in the grid, keep/discard, crop if needed.
3. Each Walk commits to a Trip: by default its own new single-Walk Trip named after itself,
   or an existing Trip chosen at commit.
4. Copy, verify, write manifests + thumbnails, update the Archive Index.
5. After backup confirmation, explicit Cleanup removes imported files from the Source.

### Historical folders
Same Triage with historical defaults: keep-all stance, Trip/Walk titles and date fallbacks
harvested from folder names/paths, EXIF gaps filled from file dates. Same safety model.

### Browsing and finding
Timeline of Trips (covers, titles, dates, locations, counts) → Trip → Walks → photo grid.
Map mode plots every located Walk. Search finds filenames and AI descriptions. All three run
from the index alone — no photo bytes required.

### Describing
On demand, per photo / Walk / Trip, via LM Studio; batch queue for historical backfill.
Never automatic during Triage.

### Publishing
Push a Trip or Photo Log to Google Photos as an album (original quality); membership badges
recorded in manifests. One-time manual marks for pre-app uploads.

## Functional Requirements

Carried forward unchanged from the triage era (all shipped): session/triage persistence and
resume; grid-first review with keyboard/UI parity; burst + configurable time-cluster
grouping; deterministic collision-safe archive file naming (`YYYY-MM-DD-slug-NNN.ext`);
copy verification; walk/per-file Markdown manifests + JSONL session logs; explicit
verification-gated Cleanup; settings/backup export-import; non-destructive versioned crop.

New for 1.0 (per PDT-2026-07-03-097, WP1–WP7): Walk/Trip domain model and archive layout v2
with migration tool; multi-source Triage and Walk-boundary proposals; Archive Index +
thumbnail backfill; travel-mode byte-read guard; Timeline, Map mode, and FTS search;
Locations; LM Studio descriptions; Google Photos push; historical Triage defaults.

## Success Criteria

- The user runs their entire photo life in the app: new-photo triage, historical ingestion,
  browse/search/map anywhere, Google Photos publishing — without Finder and without opening
  a database.
- The Archive remains a plain-text-legible folder tree that would outlive the app.
- A named photo can be found by content ("swans", "Blenheim") in seconds from either
  machine.
- The travel machine never accidentally downloads photo bytes.

## Risks

- Archive layout v2 migration touches every existing folder and manifest — mitigated by
  dry-run reports, verification, and OneDrive move-as-metadata sync (ADR 0001).
- Google Photos API restrictions (post-2025-03) limit the app to app-created media;
  membership of pre-app uploads is manual by design.
- The online-only detection heuristic (allocated-size≈0) is unofficial; validated
  empirically before travel-mode reliance (ADR 0002).
- LM Studio model quality varies; descriptions are regenerable by design, so model upgrades
  re-run cheaply.
