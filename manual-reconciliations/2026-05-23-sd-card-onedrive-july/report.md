# SD Card vs OneDrive July 2025 Reconciliation

## Result

- OneDrive source: `/Users/dominiklukes/Library/CloudStorage/OneDrive-Personal/Pictures/2025/07/`
- SD card source: `/Volumes/EOS_DIGITAL/DCIM/`
- OneDrive JPGs checked: `884`
- OneDrive `.on1` sidecars found: `884`
- SD card JPGs checked: `2772`
- Exact SD-card JPG matches: `884`
- Filename-token misses: `0`
- Size mismatches: `0`
- SHA-256 mismatches: `0`

## Safe-delete candidates

The 884 exact matches are safe-delete candidates from the SD card, subject to your normal backup policy. Each candidate matched on:

- Canon `IMG_####` token
- byte size
- SHA-256 hash

The matched SD-card JPGs run from:

- first: `/Volumes/EOS_DIGITAL/DCIM/100CANON/IMG_0381.JPG`
- last: `/Volumes/EOS_DIGITAL/DCIM/100CANON/IMG_1264.JPG`

Do not treat other SD-card files as covered by this check.

## App-visible log

Inserted manual PhotoDiaryTriage log:

- title: `2025-07 OneDrive exact matches on EOS_DIGITAL`
- session id: `75542B9E-FDD8-538E-A96D-9838E17C9655`
- status: `imported`
- items: `884`
- source folder: `/Volumes/EOS_DIGITAL/DCIM`

The app session database was backed up before insertion:

- `/Users/dominiklukes/Library/Application Support/PhotoDiaryTriage/sessions.sqlite.before-manual-july-sd-log-20260523T103200Z`

## Evidence files

- `summary.json`: aggregate counts
- `onedrive-july-vs-eos-digital.csv`: full comparison table
- `sd-card-exact-delete-candidates.csv`: SD-card JPGs that exactly match OneDrive July JPGs
- `app-visible-log.json`: inserted PhotoDiaryTriage manual log details

## Deletion boundary

No files were deleted. The exact-match list supports deleting the 884 SD-card JPGs if you are satisfied that OneDrive is the intended retained copy. It does not prove that unrelated SD-card files, RAW files, or non-JPG files are backed up.
