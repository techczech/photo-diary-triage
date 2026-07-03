# PDT-2026-07-03-097 WP1.a — archive layout v2 + migrator (report)

item_id: PDT-2026-07-03-097
shipped_release_version: 0.4.0 (build 131)
shipped_feature_slug: archive-layout-v2

## Summary of what changed

First half of WP1: the on-disk layout moves to v2 (ADR 0001) and a migration tool converts
the existing app-written archive.

- **Naming (Utilities.swift, DateFormatting)**: new `archiveTripFolderName` (`06-June`, or
  `06-June-Trip-Slug` for named Trips), `archiveWalkFolderName` now uses abbreviated
  weekdays (`02-Tue-Walk-in-blenheim`; token style in `DateFormatting.weekdayFormat`,
  English default, Settings exposure comes with the Triage rework), and new
  `archiveFileStem` giving date-bearing file names (`2026-06-02-walk-in-blenheim-NNN.ext`).
  Legacy name builders kept for the migrator.
- **Discovery during implementation** (ADR 0001 corrected): legacy file stems embedded the
  walk folder name with NO date (`02-Thursday-Port-meadow-001.jpg`), contradicting the
  "full date in file names" decision — so migration renames files, not just folders.
- **ArchivePlanner** writes v2 paths: `YYYY/MM-MonthName/DD-Ddd-Slug/` with date-bearing
  stems. (Named-Trip targeting arrives with the Triage rework, WP1.b.)
- **ArchiveLayoutMigrator** (new): plans → executes → verifies. Recognises legacy months
  (`"03 - March"`) and legacy walk folders (`02-Monday-Slug`); renames/moves folders,
  renames media stems and sidecars (walk manifest + session log follow the walk name),
  rewrites absolute paths, relative paths, and stems inside all `.md`/`.json`/`.jsonl`
  sidecars; removes emptied legacy month folders; skips pre-app folders (e.g. `2020/03/28`)
  untouched — those are WP7 historical-processing material.
- **File > Migrate Archive Layout…**: writes a full dry-run plan to
  `_layout-migration-dry-run.txt` in the archive root, asks for confirmation, executes off
  the main thread, verifies, writes `_layout-migration-report.txt`, refreshes the browser.
- **Bug fix**: archive year folders were only recognised for 2020–2029 (`^202\d$`) in the
  browser and year inspector; now `^(19|20)\d\d$`, so historical years will be visible.
- **ArchiveCopySurveyor** now surveys legacy, v2-month, and named-Trip folders.

## Files changed

- Sources/PhotoDiaryTriage/Utilities.swift, ArchivePlanner.swift, ArchiveCopySurveyor.swift,
  BrowserViewModel.swift, AppState.swift, AppCommands.swift
- Sources/PhotoDiaryTriage/ArchiveLayoutMigrator.swift (new)
- Tests/PhotoDiaryTriageTests/ArchiveLayoutMigratorTests.swift (new; 7 tests)
- docs/adr/0001 (file-naming consequence corrected), APP_RELEASE.env

## Verification performed

- `swift build` passes; `swift test --filter ArchiveLayout` — 7/7 pass (naming formats,
  plan recognition, execute+verify round-trip on a synthetic legacy archive, idempotence:
  second plan is empty).
- Full `swift test` currently fails on PRE-EXISTING issues unrelated to this change: one
  crop-nudge expectation in ReviewInteractionTests and a fatal-error crash mid-run.
  Logged as a follow-up below.
- 0.4.0 bundled and installed to /Applications/Walkfolio.app.

## Known gaps / follow-ups

- Pre-existing test failures (ReviewInteractionTests crop nudge; fatal error aborting the
  suite) need triage — they predate this work.
- WP1.b remains: Trip/Walk models in code, multi-source Triage, Walk-boundary proposals,
  commit-to-existing-Trip, Walk moves between Trips as a first-class UI operation, weekday
  token Setting.
- The migrator does not create a backup; OneDrive version history is the safety net, and
  the dry-run report is written before anything moves. Consider a `--copy-first` mode if
  the first real run feels risky.

## Test handoff

**Please test APP_VERSION 0.4.0 (build 131), /Applications/Walkfolio.app.** Two things:

1. **File > Migrate Archive Layout…** — first just read the dialog and then CANCEL; check
   `_layout-migration-dry-run.txt` in your archive root and tell me whether the planned
   renames look right (correct months, weekday abbreviations, file stems, and pre-app
   folders listed as skipped). Run the actual migration only when the dry run reads clean.
2. Import a small test walk from any folder: it should land in `YYYY/MM-MonthName/
   DD-Ddd-Title/` with files named `yyyy-MM-dd-title-001.jpg` etc.
