# PDT-2026-05-23-057: Source Archive Copy Survey

## User Request Summary

When viewing the current SD card, survey all source files, including files that are not in photo logs, and show whether each file already has an archive copy on disk. The result should appear as metadata in the SD-card view so it is clear which files still need triage.

## Constraints

- Do not rely only on photo-log membership.
- Use archive-disk evidence outside the live source scan.
- Keep the source view faithful to all current SD-card files.
- Avoid destructive cleanup or moving files.
- Keep the survey read-only and visible in grid and list review views.
- Prefer archive manifests and file metadata over filename-only matching.

## Implementation Intent

- Add an archive copy survey helper that scans Markdown file manifests under the configured archive root.
- Match source items against archived files by source file name, archive file size, and captured timestamp when available.
- Add archive-copy metadata to review snapshots for source inbox items.
- Render an `On Disk` badge when a source item already has an archive copy but is not already covered by the photo-log ownership badge.
- Add regression coverage for source items that are copied on disk but not in a photo log.

## Test Conditions

- A source inbox item matching an archive manifest and existing archive file receives disk-copy metadata.
- A source inbox item without a matching manifest does not receive disk-copy metadata.
- Existing photo-log ownership badges continue to win over disk-only badges.
- Full tests continue to pass.

## Success Criteria

- The SD-card view distinguishes files already copied to disk from files that still need triage.
- The survey works for files not present in any saved photo log.
- The implementation remains read-only.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.18
- APP_BUILD: 95
- APP_FEATURE_SLUG: source-archive-copy-survey
