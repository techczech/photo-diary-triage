# PDT-2026-05-23-065: Manual SD card OneDrive July log

## User Request Summary

- Investigate which photos from `/Users/dominiklukes/Library/CloudStorage/OneDrive-Personal/Pictures/2025/07/` are on the SD card.
- Do it manually outside the app because this is a one-off.
- Make the status visible inside PhotoDiaryTriage.
- Provide evidence so the user can confirm which SD card photos are safe to delete.

## Constraints

- Do not delete any source, SD card, OneDrive, or app-support files.
- Treat `/Volumes/EOS_DIGITAL` as the SD card unless evidence says otherwise.
- Use exact evidence for safe-delete candidates; filename-only matches are not enough.
- Keep OneDrive `.on1` sidecars out of the photo match count unless reporting sidecar coverage separately.
- Back up app session storage before writing a manual visible log.
- Keep the manual log distinguishable from normal app-created photo logs.

## Implementation Intent

- Compare OneDrive July 2025 JPGs with SD card JPGs by camera filename token, file size, and SHA-256.
- Write a durable local reconciliation report and machine-readable match table.
- Insert one manual PhotoDiaryTriage photo log for exact matches so the app can show the matched SD card photos as already copied/verified.
- Keep unmatched and weak matches out of the app-visible safe-delete log.

## Test Conditions

- Verify JSON/CSV report counts.
- Verify `sessions.sqlite` is backed up before modification.
- Verify the PhotoDiaryTriage session store can load the inserted manual log.
- Launch `dist/PhotoDiaryTriage.app` after insertion.

## Success Criteria

- Exact-match count and unmatched count are reported.
- App-visible log contains only exact SD card to OneDrive JPG matches.
- The report explains what is safe to delete and what still needs manual review.
- No files are deleted.

## Current Status

- status: approved_for_implementation
- target release version: no app code release; manual data operation only
- target feature slug: `manual-sd-card-onedrive-july-log`
