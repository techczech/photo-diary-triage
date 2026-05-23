# PDT-2026-05-23-065: Manual SD card OneDrive July log report

## Summary

- Compared OneDrive July 2025 JPGs against the mounted `EOS_DIGITAL` SD card.
- Confirmed `884` exact SD-card JPG matches by `IMG_####` token, byte size, and SHA-256.
- Confirmed all `884` matched OneDrive JPGs have matching `.on1` sidecars in the OneDrive July folder.
- Wrote a full reconciliation report and CSV evidence files.
- Backed up the app session database, then inserted a manual PhotoDiaryTriage log containing exactly the `884` matched SD-card JPGs.
- Deleted no files.

## Files Changed

- `changelog/backlog/PDT-2026-05-23-065-manual-sd-card-onedrive-july-log.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/changelog/PDT-2026-05-23-065-manual-sd-card-onedrive-july-log-report.md`
- `manual-reconciliations/2026-05-23-sd-card-onedrive-july/report.md`
- `manual-reconciliations/2026-05-23-sd-card-onedrive-july/summary.json`
- `manual-reconciliations/2026-05-23-sd-card-onedrive-july/onedrive-july-vs-eos-digital.csv`
- `manual-reconciliations/2026-05-23-sd-card-onedrive-july/sd-card-exact-delete-candidates.csv`
- `manual-reconciliations/2026-05-23-sd-card-onedrive-july/app-visible-log.json`

## External Data Written

- Inserted PhotoDiaryTriage session id `75542B9E-FDD8-538E-A96D-9838E17C9655` into `/Users/dominiklukes/Library/Application Support/PhotoDiaryTriage/sessions.sqlite`.
- Backed up the database first to `/Users/dominiklukes/Library/Application Support/PhotoDiaryTriage/sessions.sqlite.before-manual-july-sd-log-20260523T103200Z`.

## Verification Performed

- Confirmed all `884` OneDrive JPGs have exact SD-card JPG matches.
- Confirmed the exact-delete-candidates CSV has `884` rows.
- Confirmed the inserted PhotoDiaryTriage log exists in SQLite with title `2025-07 OneDrive exact matches on EOS_DIGITAL` and `884` media items.
- Launched `dist/PhotoDiaryTriage.app`.

## Known Gaps Or Follow-Up Items

- Computer Use again returned only `remoteConnection`, so the app-visible log was verified through SQLite and app launch, not a visual accessibility-tree read.
- This check covers JPGs in the OneDrive July folder and matching SD-card JPGs only. It does not prove unrelated SD-card files, RAW files, or non-JPG files are backed up.

## Release

- shipped release version: no app code release; manual data operation only
- shipped feature slug: `manual-sd-card-onedrive-july-log`
