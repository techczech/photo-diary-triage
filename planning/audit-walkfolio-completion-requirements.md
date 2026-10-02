---
title: Walkfolio full-scope completion evidence and remaining acceptance
status: implementation_in_progress
updated: 2026-10-02
release: 0.7.14
build: 150
sources:
  - planning/dictated-idea-scope.md
  - CONTEXT.md
  - PRD.md
  - DESIGN.md
  - changelog/backlog/PDT-2026-07-03-097-photo-diary-completion-plan.md
  - docs/adr/0001-archive-layout-trips-as-month-level-folders.md
  - docs/adr/0002-archive-index-derived-jsonl-in-pinned-folder.md
  - docs/adr/0003-archive-browse-includes-unorganised-folders.md
  - docs/adr/0004-folder-scoped-archive-thumbnail-preparation.md
---

# What Walkfolio must achieve, and the evidence

**The intended result is a usable photographic life archive, from selecting new camera
and phone photos to finding and sharing decades of older material.** The requirements
below retain the whole approved completion scope. The new tests are evidence of specific
behaviour; they do not replace native or real-provider acceptance.

## Decisions recovered from the record

- CONTEXT.md and ADR 0001 explicitly settle the plain month as the default Trip for
  standalone Walks. A contrary phrase in the completion plan, PRD workflow and later
  implementation plan conflicted with their own domain sections. Those summaries now
  match the settled canonical decision and existing `.defaultMonth` proposal behaviour.
  Named/new/existing targets and historical title proposals remain available. This audit
  reconciles the documents; it introduces no new default or scope exclusion.
- The old Map gate is passed: `changelog/backlog.jsonl` line 555 records user approval of
  PDT-2026-05-30-096 on 2026-07-03 at 19:10 UTC. The old renderer's acceptance cannot
  establish that the new archive-wide Map and present navigation work natively.
- The tracking log contains 93 unique `status_normalized` items and the explicit
  supersession of crop items 076/079. A tracking cleanup receipt establishes bookkeeping,
  not a test of today's app.
- ADR 0003 retains unorganised historical folders alongside recognised Trips. Folder depth
  and a supposed 2016 date boundary are not recognition rules. ADR 0004 adds explicit
  preparation for one open folder, with serial hydration/eviction, cancellation and a
  15 GB floor; ordinary opening remains read-only.

## Requirement traceability

| Original aim | Current implementation and fixture evidence | Remaining acceptance |
|---|---|---|
| WP0: archive-manager identity, configurable Walk/Trip labels, tracking and old Map gate | Walkfolio display name; canonical terms unchanged; settings labels; current PRD/DESIGN; approval receipt above. | Read present controls and labels in the packaged app. |
| WP1: camera + phone, multiple same-day Walks, physical Trips, append/move/migration | `WalkTripModelTests`, `ArchiveMoveReliabilityTests`, `ArchiveLayoutMigratorTests`, `TripLocationTests` and the composed Google journey cover distinct Walk destinations, shared Trip membership, canonical IDs, mixed layout and interrupted moves/migration. | Reviewed migration dry run and verification on a backed-up copy of the real archive. |
| WP2: durable thumbnails/index, rebuild and index-only Travel | `ArchiveIndexTests`, `ArchiveTravelTests`, `ArchiveOriginalViewingTests`, `ThumbnailSchedulerTests`, `TravelModeSyncTests`: complete hashed generations, fresh root with only index/thumbs, no originals/manifests/enumeration, RAW/crop grouping, explicit per-path byte grants and bounded preparation. | Actual OneDrive placeholders, allocated-size heuristic, download/eviction, low-space floor and shared-machine synchronisation. |
| WP3: Timeline/Contact Sheet, covers, navigation, Map and full-text search | ArchiveNavigationTests: measured columns/year rows, retained Back, photo Open, contextual Map ownership and projection reuse across 1,000 moves over 50,000 photos; existing catalogue/Map/review suites remain green. | Further implementation: asynchronous bounded covers and sidebar focus. SearchWorkflowTests covers visible exact-hit routing, mixed keyboard actions, folder empty/error/retry, request/root/context races, refresh-safe Compare, isolated FTS ownership and Travel-label search. Native layout/focus/responsiveness remains required. |
| WP4: contextual Walk/photo/shared locations, pin/GPS precedence, Trip label | `ArchiveLocationTests`, `ArchiveMapTests`, `TripLocationTests`: spherical centroid, raw GPS retained, overrides/clear, shared group recovery, canonical rebuild, append/move and fresh Travel. | Native assignment controls and Map rendering, including clear/fallback. |
| WP5: local photo/Walk/Trip descriptions, immutable provenance, historical queue | `DescriptionTests`: explicit model and bounded payload, dependencies, model/date stamps, human notes separate, active revision search, cancellation/context, local receipt/response recovery and thumbnail-only Travel. | LM Studio was not listening at 127.0.0.1:1234. Chosen real vision model, response quality and native model selection still require a live check. |
| WP6: original-quality albums, membership, manual historical marks, verify/retry/quota | `GooglePhotosTests`: injected Desktop OAuth/PKCE/state/scopes, loopback and refresh races; reviewed account/destination; exact streamed bytes; interrupted offsets/expiry; unknown album reconciliation; canonical receipts and membership; cancellation/quota; Travel badges. | Actual Desktop OAuth project/client, live disposable Google account and originals, album/append/retry/membership verification. No real account or private-photo delivery ran. |
| WP7: historical keep-all, titles/dates, ordinary triage and verified cleanup | `HistoricalTriageTests`, `ArchiveReliabilityTests`, `ImportWorkflowTests`: hint provenance, absent/conflicting dates, saved choices, actual AppState confirmed Copy/reopen/retry, equal-size corruption and narrowly recorded archive-source cleanup. | End-to-end on one copied real old folder, reviewed dates/Trip and gated cleanup. |
| Existing triage: mouse/keyboard/grid, bursts/groups, preview/compare/crop | Existing `ReviewInteractionTests`, `SelectionManagerTests`, `CropServiceTests`, scheduler and lifecycle suite remains green. | Packaged native selection/focus/keyboard/compare and realistic large sessions. |
| Original persistence aim: manual app-state backup and recovery | `BackupRecoveryTests`: 34 cases for immediate/multiple-session edits, deletion, precise and legacy formats, strict corrupt/locked reads, SQLite/settings/journal failures, prepared/committed recovery, failed rollback, empty retry, RAM fallback, stale editors/context, suspended cleanup and atomic multi-Source membership. | Native export/import file pickers on disposable state. Power-loss behaviour on every supported filesystem is not certified by injected failures. |
| Complete workflow without Finder or missing packages | `GooglePhotosTests` composed camera + phone → two same-day Walks/named Trip → locations → six descriptions → mock album membership → deleted/rebuilt index → fresh Travel grid/search/Map. | The original whole native journey using disposable real copies and real local/remote providers. |

## Release evidence and completion rule

All 423 tests pass in 23.227 seconds; baseline 190. Full output is /private/tmp/walkfolio-search-full-final.log. Reports 100–110 record the reliability releases. Astra's final focused source review found no further material defect; its reviews
are not runtime/provider evidence. Claude Opus was consulted on the public-source recovery
approach earlier in the same task.

The composed fixture journey is verified. A subsequent WP3 source audit found outstanding implementation defects: adaptive grid navigation, visual year order, Back selection, Map keyboard targets, repeated projection computation, invisible photo search results, empty/error folder feedback, synchronous cover reads and sidebar focus. Navigation and search/folder recovery now ship; synchronous cover reads and sidebar focus require further implementation before whole-scope implementation can be claimed. Version 1.0 is not accepted
until the original real-copy, native, OneDrive, LM Studio and Google test-account conditions
pass. Original full-workflow acceptance remains required; the 0.7.14 request isolates native search/folder recovery with disposable synthetic data while implementation continues. It requires no routine
product decision, launches no watcher and authorises no automatic external delivery.
