# PDT-2026-03-26-031 Legacy Session Kind Default Fix Report

- Item ID: `PDT-2026-03-26-031`
- Title: `Legacy session kind default fix`
- Shipped release version: `0.1.69`
- Shipped feature slug: `legacy-session-kind-default-fix`
- Status: `implemented`

## Summary

Fixed the compatibility bug that made older persisted sessions claim ownership of the entire source card. Sessions saved before the walk-draft feature now decode as inbox sessions unless they explicitly declare `sessionKind`, so legacy data no longer hides all files on `/Volumes/EOS_DIGITAL/DCIM`.

## Files Changed

- [Sources/PhotoDiaryTriage/Models.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/Models.swift)
- [Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-031-legacy-session-kind-default-fix.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-031-legacy-session-kind-default-fix.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Notes

- Explicit modern saved walk drafts are unaffected because they persist `sessionKind`.
- Legacy sessions still reopen normally, but they no longer subtract all source files from the rescanned inbox.
