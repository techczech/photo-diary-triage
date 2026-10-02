---
item_id: PDT-2026-10-02-104
title: Historical folders and confirmed Copy recovery
shipped_release_version: 0.7.8
shipped_build: 144
shipped_feature_slug: historical-triage
status: shipped_pending_native_check
---

# Walkfolio 0.7.8: organise old folders and resume confirmed copies

A dedicated historical source action keeps the chosen root and starts new photos kept. Reopening restores historical date preference and stable IDs/exclusions/RAW decisions for unchanged files, while refreshing companion and crop relationships. Date/title hints feed normal Walk grouping and default/new/existing Trip planning. Valid camera dates take precedence by default; explicit folder-date preference retains the original camera date, conflict and day/month/year precision. Date cards avoid inventing capture times from date-only evidence.

The confirmed Walk/Trip plan is persisted before the first Copy. Failed imports reopen the exact recorded targets in a locked recovery sheet. Editing, adding, cropping, deleting or replacing that log is prevented until recovery finishes; a separate Source remains available. Candidate prior copies are verified by SHA-256 before recognition. Historical recognition survives corrected dates and archive relocation, runs through Add Source too, respects travel byte policy and cannot become Cleanup eligibility.

Archive-source Cleanup is limited to an explicit recorded historical root with a completed own import into a separate destination. It retains main-role and backup gates, checks the entire selected original/RAW batch, rejects aliases/missing or changed copies/canonical material, journals each deletion and resumes partial cleanup. The app asks for confirmation before running it; uncopied files and source directories remain. Resolved destination ancestors are checked before journalling so linked Trips cannot write back into the historical source.

## Files changed

HistoricalSource models parsing/evidence/safety; FileScanner and SessionManager feed normal Triage. Models, ManifestRenderer and index/loading preserve date evidence. AppState, source menu, toolbar and commit sheet expose historical intent and confirmed-plan recovery. ArchiveCopySurveyor and ImportCoordinator verify recognition and narrow cleanup. HistoricalTriageTests covers actual app actions and service failures; existing path assertions now compare resolved filesystem identities. README and the development plan describe current completion boundaries.

## Verification

- 279 tests in two suites passed in 12.986 seconds, up from 261. The new tests include parameterised cleanup and Trip-target cases.
- Actual AppState Copy → edited Walk/Trip → second-file failure → new AppState with shared persisted store → open saved log → locked same-plan retry → successful exact destinations passes.
- Slow source addition cannot race Copy or overwrite newer metadata; same-click Copy cancels an addition before it scans. Pending-copy protection survives archive disconnection and reopening.
- A failed session save prevents copying. Attempted metadata/selection/Add Source/deletion during recovery leave the saved log intact.
- Historical versus camera defaults, reload with a new/removed RAW companion, saved date preference from an unrelated current session, complete/month/year/invalid/fallback dates and honest date display pass.
- Canonical date evidence and index reconstruction, root relocation/corrected-date recognition, same-size different bytes, Travel refusal and non-cleanable recognition pass.
- Recorded archive-source cleanup success/retry retains uncopied files/directories. Missing destination, missing own journal, hardlink aliases, canonical contamination, Travel role and recognised-copy markers retain all sources.
- Resolved destination symlinks fail before writing an import journal or canonical source material. Hidden canonical descendants are excluded consistently by both scanner and validation.
- Cancelling a confirmed recovery sheet before its journal starts retains edited targets and identities; confirmation completes the same original plan.
- Astra reviewed the implementation repeatedly; all reported P1/P2 findings were corrected and covered.
- The tested signed bundle is installed as 0.7.8 build 144. Strict signature and built/installed executable equality checks passed; prior installation retained at `/private/tmp/Walkfolio-before-historical-triage-0.7.8.app`.
- No headed UI, live archive rebuild/migration/cleanup or real-photo hydration was used during development. Native source picker/date review/confirmation and actual OneDrive remain separate checks.

## Limits and follow-up

A historical destination moved after import will fail the conservative exact recorded-destination Cleanup check; retain the source or complete Cleanup before moving. Partial dates are explicit provenance anchored for folder grouping, not a claim of exact capture time. Local archive locking remains cooperative rather than distributed across OneDrive machines.

Trip location-label overrides, on-demand LM Studio descriptions and Google Photos delivery remain approved work. Development continues independently.
