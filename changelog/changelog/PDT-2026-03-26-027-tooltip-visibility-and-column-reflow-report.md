# PDT-2026-03-26-027 Tooltip Visibility And Column Reflow Report

- Item ID: `PDT-2026-03-26-027`
- Title: `Tooltip visibility and column reflow`
- Shipped release version: `0.1.65`
- Shipped feature slug: `tooltip-visibility-and-column-reflow`
- Status: `implemented`

## Summary

Removed the hard cap on review card width so shrinking review columns now reflows the grid to consume the available width instead of stalling at the old fixed maximum. This directly addresses the grid column resize issue reported by the user.

## Files Changed

- [Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift)
- [Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-027-tooltip-visibility-and-column-reflow.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-027-tooltip-visibility-and-column-reflow.md)

## Verification

- `swift test`
- `./scripts/build_app_bundle.sh`
- Confirmed the new release metadata was written into the app bundle

## Notes

- The tooltip timing/visibility complaint is still a follow-up item and was not changed in this slice.
- Sidebar hover and tooltip behavior remain tracked separately.
