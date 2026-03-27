# PDT-2026-03-27-034 Corrupt Session Tolerance Report

- Item ID: `PDT-2026-03-27-034`
- Title: `Corrupt session tolerance`
- Shipped release version: `0.1.72`
- Shipped feature slug: `corrupt-session-tolerance`
- Status: `implemented`

## Summary

Changed persisted-session recovery so corrupt SQLite rows are skipped instead of aborting the entire startup/source-load path. This lets the app continue with the remaining valid sessions, normalize the persisted inbox set, and reopen the live EOS source inbox even when old stored rows are damaged.

## Files Changed

- [Sources/PhotoDiaryTriage/SessionStore.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/SessionStore.swift)
- [Tests/PhotoDiaryTriageTests/SessionStoreTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/SessionStoreTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-27-034-corrupt-session-tolerance.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-27-034-corrupt-session-tolerance.md)

## Verification

- `swift test`
- `./scripts/build_app_bundle.sh`
- Relaunched the packaged app against the existing local support data and verified via `log show` that it:
  - skipped the corrupt persisted row
  - resolved `/Volumes/EOS_DIGITAL/DCIM`
  - opened a live session with `1751` items

## Known Gaps / Follow-up

- The store now tolerates corrupt rows, but it does not yet export or separately archive those discarded rows for forensic recovery.
