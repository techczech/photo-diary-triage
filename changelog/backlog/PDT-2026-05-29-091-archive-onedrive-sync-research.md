# PDT-2026-05-29-091 archive browsing + OneDrive awareness + Markdown sync (research)

item_id: PDT-2026-05-29-091
title: Archive view, travel-machine OneDrive awareness, no-auto-download, Markdown sync
status: research
target_release_version: TBD
target_feature_slug: archive-onedrive-awareness

## Status

RESEARCH list — items to investigate/design, not approved work. Grounded in current code
(see PDT-2026-05-29-089 map for byte-reading paths and manifest layout).

## R1 — Comprehensive archive browsing (current view is not intuitive)

Today: rigid drill-down only. `BrowserViewModel.buildArchiveYearNodes/Month/Walk` scans the
filesystem (year `^202\d$` → month → walk folder); each node shows only a count subtitle;
the user must click year → month → walk before any grid appears. No overview, no thumbnails
until a walk is opened, no cross-walk view.

Research / options:
- A scrollable **timeline / all-walks overview** (flat list of walks across all months with
  cover thumbnail + count + location), not just nested folders. (Mylio/PhotoPrism/Tonfotos
  pattern.)
- A **calendar / heatmap** of activity by day/month to jump straight to a date.
- A **map view** of walks by location (overlaps PDT-2026-05-29-090 Slice C).
- Show **richer per-node metadata** from the walk `.md` manifest (location, date range,
  imported/excluded counts) instead of just "N walk folder(s)".
- Decide whether archive overview is a new top-level mode or an enriched sidebar+grid.
Open question: cover thumbnails for archive walks must respect R3 (no auto-download) — use a
synced cover or a manifest-recorded thumbnail, not an on-demand fetch.

## R2 — Travel-machine OneDrive awareness (counts + non-downloaded)

Want: on the travel machine, know what is in OneDrive — totals, and which items are
downloaded vs online-only — without opening the photos.
Current: `archiveMachineRole` (.mainArchive/.travel) only gates source cleanup; no
awareness of OneDrive contents or download state. `oneDrivePicturesRoot` is just a path.

Research / options:
- Derive archive inventory from the **Markdown/JSON manifests** (R4), which list every
  imported file with relative paths and counts — gives totals "what's in the archive" with
  zero photo bytes.
- Per-walk badges: "12 photos · 0 downloaded locally · 12 in OneDrive".
- Surface counts in the sidebar/overview (ties to R1).

## R3 — Never auto-download cloud files not present on the travel machine

Risk (confirmed): browsing/thumbnailing the archive reads file bytes and WILL trigger
OneDrive downloads of online-only files. Byte-reading paths over the archive:
- `PreviewStore.generateThumbnail` (QLThumbnailGenerator) — grid thumbnails.
- `DecodedImagePipeline.decodeImage` (CGImageSource) — full preview / zoom.
- `CropService.crop` (CGImageSource) — cropping an archived original.
- (`FileScanner` archive load uses `.fileAttributesOnly`, so scanning itself is safe; but
  the grid still calls `requestThumbnail` for visible archive items.)
There is currently NO check for online-only/dataless files anywhere.

Hard constraint found in research: **macOS exposes no clean public API** to detect a
File-Provider "online-only / dataless" file without risk; the File Provider system shows the
cloud icon itself and Spotlight won't hydrate dataless files. Options to investigate:
- Heuristic: compare `URLResourceKey.totalFileAllocatedSizeKey` (≈0 for a dataless
  placeholder) vs `.fileSizeKey` (logical size) — flag "not downloaded" when allocated≈0 and
  logical>0. Validate empirically against the user's OneDrive Files-On-Demand setup.
- Policy gate: in travel mode, DEFAULT to **not** generating thumbnails/previews for archive
  files; show a manifest-recorded placeholder/cover and a "Download to view" action that
  reads bytes only on explicit user request.
- Never read bytes for archive items flagged not-downloaded; surface that state in the UI.
Open question: confirm OneDrive on this Mac uses the new File Provider On-Demand model (it
does on modern macOS) so the allocated-size heuristic is the right signal.

## R4 — Sync archive contents across home/travel machines: Markdown only

Want: keep the two machines' knowledge of the archive in sync by syncing ONLY the lightweight
text files, never the photos.
Current manifest layer already exists per walk (no photo bytes):
- `<walk>.md` (walk summary: title, location, date, counts, imported/excluded lists)
- `<file>.md` (per-file: id, relative paths, EXIF, GPS, walk title/location)
- `<walk>-session-log.jsonl` (commit/verify event log)
- `<file>.crops.json` (crop history)
- `.photo-diary-triage/photo-logs/<sessionID>.json` (existing per-log sync doc on OneDrive root)

Research / options:
- These `.md`/`.json(l)` files are tiny and already carry OneDrive-relative paths, so syncing
  just them gives each machine a full picture of archive contents (R1/R2) without photos.
- Mechanism choices: (a) let OneDrive itself keep the manifests "always available" (pin the
  manifest files / a `.photo-diary-triage` index folder) while photos stay online-only; (b) a
  dedicated lightweight index the app maintains (aggregate manifest → one index file synced
  via the existing `.photo-diary-triage` folder); (c) git/rsync of just the text files.
- Build an **archive index** by walking the manifests into an in-app catalog the travel
  machine reads to render R1/R2 offline.
Open questions: conflict handling if both machines edit metadata; where the canonical index
lives; whether to extend the existing PhotoLogSyncStore JSON sync to a full archive index.

## Sources

- OneDrive Files On-Demand on macOS (File Provider; dataless files; no override of cloud icon):
  techcommunity.microsoft.com "Inside the new Files On-Demand Experience on macOS";
  support.microsoft.com Files On-Demand for Mac.
- No public dataless-detection API: Apple Developer Forums (File Provider tag); NSURL docs.
- Archive browsing patterns (timeline/calendar/map, event clustering): mylio.com,
  github.com/photoprism/photoprism issue #152, tonfotos.com, cyme.io best-photo-organizer.
