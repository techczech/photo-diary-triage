# Photo Diary Triage PRD

This PRD is subordinate to [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md) for UX, interaction, shortcut, layout, popup, persistence, and launch-model decisions. If implementation or future planning conflicts with the design-governance document, [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md) is authoritative.

## Product Summary

Photo Diary Triage is a local-only macOS app for reviewing photos directly from an external SSD, selecting the keepers, importing only those chosen files into a structured archive, and generating durable Markdown and JSONL records for long-term reference. The product is optimized for a solo photography workflow where speed, safety, and archival clarity matter more than in-app editing.

## Problem

Current photo-walk workflows create too much friction:
- importing everything first creates avoidable duplicate storage
- deleting inside the import flow is risky
- archived folders often lack descriptive context
- grouping bursts and time-related images is manual and repetitive
- metadata ends up trapped in ad hoc tools or databases

## Goals

- Triage directly from the source SSD without modifying it during review.
- Selectively import only kept images into a structured archive.
- Preserve fast working state in SQLite while exporting durable text records.
- Support burst and looser time-cluster navigation for faster review.
- Make SSD cleanup a distinct, explicit, verification-gated step.
- Preserve a grid-first review model for final photo content.
- Persist settings and session memory across launches.
- Support manual backup export/import of app state.

## Non-Goals

- RAW editing, color grading, or deep photo adjustments
- cloud sync or multi-user collaboration
- production integration with LM Studio, GPX, or maps in v1
- bulk historical migration workflows beyond repeating the one-folder session flow

## Primary User

A single photographer returning from a walk with a folder of images on an SSD and wanting to quickly choose what deserves archival import, preserve context, and avoid unnecessary duplicate storage on one disk.

## Core Workflow

1. User chooses a source folder on the SSD.
2. App scans supported image files and extracts metadata.
3. App builds burst and time-proximity groupings.
4. User reviews thumbnails and marks images for import.
5. User adds walk title, location, and notes.
6. App previews destination archive paths.
7. App copies selected files into the archive and verifies the copies.
8. App writes walk and per-file manifests plus a JSONL session log.
9. After the user confirms backup safety, app allows cleanup of imported source files from the SSD.

## Functional Requirements

### Session And Review
- Create one import session per source folder.
- Persist session state locally so unfinished reviews can be resumed.
- Show thumbnails for supported files with responsive grid navigation as the default final review mode.
- Allow toggling images between skipped and selected-for-import.
- Display burst and time-cluster counts for the session.
- Ensure every frequent review action has both UI and a keyboard shortcut.

### Metadata And Grouping
- Extract at least capture timestamp, dimensions, camera model, lens model, and basic GPS when present.
- Group files into bursts using a short threshold.
- Group files into looser time clusters using a configurable longer threshold.

### Import And Verification
- Build archive destinations using `YYYY/MM/YYYY-MM-DD-walk-slug`.
- Resolve filename collisions deterministically.
- Copy only selected files into the archive.
- Verify imported files by checking existence and basic file-size match.

### Durable Outputs
- Generate a walk-level Markdown manifest for the session.
- Generate per-kept-file Markdown manifests with YAML frontmatter.
- Generate a JSONL session log.
- Record total source files, imported files, left-behind files, and cleanup state.
- Support explicit backup export/import for app settings and session state.

### Cleanup
- Never delete or move source SSD files during triage.
- Enable cleanup only after import verification and user backup confirmation.
- Cleanup removes only imported source files, never skipped files.

## UX Requirements

- The app should feel safe: source files are untouched until explicit cleanup.
- The app should be fast enough to triage a typical photo walk folder without noticeable lag in basic thumbnail browsing.
- Status text should clearly communicate whether the session is scanning, ready, imported, verified, or cleanup-pending.
- Final photo content must default to a grid.
- Any popup, sheet, or overlay must be closable.
- Single-letter shortcuts may exist only inside explicit review focus and must never interfere with text entry.
- The intended end-user launch model is a standard macOS `.app`, not a terminal-attached process.

## Success Criteria

- A user can complete an end-to-end walk from SSD scan to verified archive import without using Finder for file organization.
- The archive contains only chosen photos.
- The source SSD retains unselected files after import.
- Durable outputs provide enough context to understand the walk later without opening the database.
- Settings and session state survive relaunch.
- Frequent actions are available both in UI and by shortcut.

## Risks

- Thumbnail generation performance may vary by source format.
- Command-line-tools-only environments may not fully support all macOS UI build/run flows without Xcode.
- SQLite schema is intentionally minimal in v1 and may need normalization later.

## Future Extensions

- LM Studio local captioning
- GPX / Garmin / Strava correlation
- map assignment and route visualization
- stronger backup verification integrations
- historical archive batch tooling
