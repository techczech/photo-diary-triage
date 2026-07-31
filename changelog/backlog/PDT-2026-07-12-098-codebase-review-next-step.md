# PDT-2026-07-12-098 Codebase review and next-step recommendation

item_id: PDT-2026-07-12-098
title: Codebase review and next-step recommendation
status: reinstalled_pending_user_confirmation
target_release_version: 0.7.0
target_feature_slug: timeline-and-search

## User request summary

Review the current Walkfolio codebase and identify how to move the product forward.

## Constraints

- Ground the review in the approved Walkfolio 1.0 completion plan, `CONTEXT.md`,
  `DESIGN.md`, current tracking records, and the actual checkout.
- Preserve the committed full scope: no MVP framing, silent deferrals, or scope cuts.
- Do not implement interaction, layout, navigation, shortcut, modal, or workflow changes
  until the user has reviewed and approved the design direction.
- Keep this planning review separate from the versioned release implementation and handoff
  sequence.

## Implementation intent

Inspect architecture, current implementation coverage, tests, tracking consistency, and
known technical risks. Recommend the next coherent release slice and show the evidence and
design decisions that must precede implementation.

## Test conditions

- Run the current full Swift test suite without changing code.
- Inspect current build metadata and source/test structure.
- Trace the current Release D prerequisites and identify mismatches with the approved plan.

## Success criteria

- A concise, evidence-backed codebase assessment.
- A prioritised recommendation tied to the existing completion plan.
- Explicit design questions or technical blockers surfaced before implementation.
- No product code or release metadata changed during the review.

## Current status

Review complete pending user direction. No implementation authorised by this item.

## Review findings

- The repository has implemented the approved completion plan through Release C
  (`APP_VERSION=0.6.0`, `archive-index`); Releases D–I remain.
- Release D has a safety prerequisite before product UI work: Archive thumbnail backfill
  currently reads every photo directly and has no bounded hydration, post-processing
  eviction, cancellation, or free-space floor. It is unsafe to run over the real dataless
  Archive as currently implemented.
- Archive browsing still walks the physical year/month/walk folder tree and loads terminal
  Walk folders with `FileScanner`; there is no Archive Index reader, Timeline model, SQLite
  Archive cache, or FTS implementation yet.
- The full Swift package builds. The test run produced no observed assertion failures but
  did not terminate after more than a minute, so it was interrupted; full-suite green
  status is not currently verified. Swift 6 sendability warnings remain in UI bindings and
  archive migration callbacks.
- The highest-value next move is a design-reviewed Release D foundation: first harden
  Archive byte lifecycle and batch safety, then implement Index reader/cache/query models,
  then present and approve the Timeline/Search interaction design before replacing the
  current folder browser.

## Archive browsing design direction

The Archive should provide two views over the same indexed Trips:

- **Timeline** is the default view. It uses wide chronological rows with a cover image,
  title, date range, location, Walk count, and photo count. It supports linear Up and Down
  keyboard navigation and makes similar Trips easy to distinguish.
- **Contact Sheet** is the compact visual view. It uses year-banded photographic tiles and
  two-dimensional arrow-key navigation for rapid recognition.

Both views preserve the same selected Trip, year position, search query, and navigation
state. The app remembers the last chosen view. A compact view control sits beside the
`Trips` heading, while global Archive search remains in the trailing side of the toolbar.

The earlier large-card grid is rejected because it consumes more space than the Contact
Sheet while exposing less metadata than the Timeline. It does not support a distinct user
task.

## Review mockup

The high-fidelity interactive mockup is in
`design/archive-0.7.0-mockup/`. It combines the Timeline and Contact Sheet over
one Archive state. Timeline is the default; the last chosen view persists.

The mockup uses resized copies of photographs from the user's local Archive.
Generated cover photography is not used.

Design QA passed at 1,440 × 1,024 and 820 × 900. Search, view switching,
selection continuity, keyboard navigation, Trip opening, the command palette,
Settings, build output, and Sites packaging tests were verified.

Status: mockup ready; waiting for user review. Production implementation remains
unauthorised until the user locks this design.

## Year-filter revision

User feedback: Trips and years appeared to be distinct destinations. A year should show
the same Timeline or Contact Sheet, filtered to that year.

Revision intent:

- Rename the complete Archive view to `All Trips`.
- Label year choices as filters.
- Group All Trips by year in both Archive views.
- Preserve the chosen view when a year is selected.
- Add representative Trips from several years using local Archive photographs, so the
  filtering relationship can be reviewed directly.

Revision completed:

- All Trips now groups Timeline and Contact Sheet content into year bands.
- Selecting 2024 keeps the active view and narrows it to the 2024 band.
- Changing from Contact Sheet to Timeline keeps the 2024 filter.
- Returning to All Trips keeps Timeline active and restores all year bands.
- Nineteen local Archive photographs provide representative Trips across five years.
- Design QA, the production build, Sites packaging tests, responsive layout, search, and
  browser console checks passed.

Status: revised mockup ready; waiting for user review. Production implementation remains
unauthorised until the user locks this design.

## Mixed historical folders revision

User feedback: the physical Archive is not uniformly organised as year, month, and Walk.
Month folders became consistent only around 2016, while earlier years contain varied
subfolder structures. The complete Archive view must therefore work before every folder has
been organised as a Trip or Walk.

Revision intent:

- Rename the complete view from `All Trips` to `Archive`, because it contains both recognised
  Trips and folders that have not yet been organised.
- Treat years as filters over the same Timeline or Contact Sheet.
- Recognise Trips and Walks from manifests rather than inferring them from folder depth.
- Present unrecognised folders as `Unorganised folders` with their own cover, date, path, and
  photo count.
- Open an unorganised folder directly into its photo grid without moving, renaming, or
  rewriting anything.
- Offer explicit organisation as a later action; never use 2016 as a hard-coded parser
  boundary.
- Keep production implementation unauthorised until the mixed Archive design has been
  reviewed and locked.

Revision completed:

- The complete destination is now `Archive`; `All Trips` no longer stands for the mixed
  collection.
- The sidebar filters the same view by entry type and by year.
- Ten recognised Trips and nine representative unorganised folders appear together across
  five years.
- The 2013 year filter shows the same Timeline or Contact Sheet with nine unorganised
  folders and no invented month or Trip layer.
- An unorganised folder opens a folder summary with `Open Photos` and a separate
  `Organise as a Trip…` action.
- All covers remain photographs from the user's local Archive.
- The production build, Sites packaging tests, interaction checks, responsive check, and
  clean browser reload passed.

Status: mixed Archive mockup ready; waiting for user review. Production implementation
remains unauthorised until the user locks this design.

## Design approval

The user approved the mixed Archive design on 2026-07-31.

The locked design contract is:

- Timeline and Contact Sheet are two views over the same Archive.
- Recognised Trips and Unorganised Folders appear together with visible type distinctions.
- A year filters the current view.
- Folder depth and the approximate 2016 transition never establish months, Trips, or Walks.
- Opening an Unorganised Folder browses its photos without file changes.
- Organising an Unorganised Folder as a Trip remains a separate explicit action.

The durable decision is `docs/adr/0003-archive-browse-includes-unorganised-folders.md`.
Production implementation must cite that decision and the locked mockup.

Status: design locked and ready for an implementation plan. No production code or release
metadata changed as part of the approval record.

## Production implementation

Implementation was authorised by the user on 2026-07-31.

The implementation is governed by:

- `docs/adr/0003-archive-browse-includes-unorganised-folders.md`
- `design/archive-0.7.0-mockup/`
- the complete Release D contract in `planning/codex-implementation-plan.md`
- `planning/archive-0.7.0-implementation-plan.md`

The shipped feature must:

- replace the physical year/month/Walk browser in Archive mode with Timeline and Contact
  Sheet views over one mixed Archive catalogue;
- recognise Trips and Walks only through Archive Index records backed by manifests;
- derive rebuildable Unorganised Folder summaries without changing the folders;
- keep year and type choices as filters over the current view;
- preserve selection and the chosen view while filters and presentation change;
- open Trips through their Walks and open Unorganised Folders directly into the existing
  photo grid;
- search indexed filenames, descriptions, titles, notes, locations, and camera information
  without reading archived photo bytes;
- keep Archive thumbnail work bounded and safe for the real dataless OneDrive collection;
- preserve keyboard and visible-control parity from the locked mockup.

Status: the user reported that the installed app still displayed 0.6. The
installed executable, Info.plist, embedded release record, and Launch Services
record identified 0.7.0 build 136, but the overlaid app directory retained its
0.6-era modification date. The bundle has now been replaced as a fresh
directory and explicitly re-registered. Its metadata, executable checksum, new
directory identity, and signature verify as 0.7.0 build 136. Waiting for the
user to confirm the visible label before the real-Archive test continues.
