# PDT-2026-03-26-030 Source Inbox Rescan Regression Fix Report

- Item ID: `PDT-2026-03-26-030`
- Title: `Source inbox rescan regression fix`
- Shipped release version: `0.1.68`
- Shipped feature slug: `source-inbox-rescan-regression-fix`
- Status: `implemented`

## Summary

Fixed the source-inbox regression introduced by the new multi-walk draft flow. Opening a source folder now rescans the actual source contents, rebuilds the inbox using the saved inbox metadata, and correctly subtracts media already assigned to saved walk drafts even when macOS resolves the same folder under `/private`.

## Files Changed

- [Sources/PhotoDiaryTriage/AppState.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AppState.swift)
- [Sources/PhotoDiaryTriage/FileScanner.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/FileScanner.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-030-source-inbox-rescan-regression-fix.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-030-source-inbox-rescan-regression-fix.md)

## Verification

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Notes

- Source-folder relative paths are now derived from symlink-resolved URLs, which prevents `/private` path aliasing from breaking ownership matching between saved drafts and rescanned inboxes.
- Reopening a source inbox rebuilds it from the live source folder every time, while preserving the existing inbox session ID and walk metadata.
