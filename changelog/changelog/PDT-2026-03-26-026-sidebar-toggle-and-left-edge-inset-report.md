# PDT-2026-03-26-026 Sidebar Toggle And Left Edge Inset Report

- Item ID: `PDT-2026-03-26-026`
- Title: `Sidebar toggle and left edge inset`
- Shipped release version: `0.1.64`
- Shipped feature slug: `sidebar-toggle-and-left-edge-inset`
- Status: `implemented`

## Summary

Restored a visible sidebar toggle in the review chrome and kept a small left gutter when the sidebar is hidden so the review grid no longer sits flush against the window edge.

## Files Changed

- [Sources/PhotoDiaryTriage/ContentView.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentView.swift)
- [Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift)
- [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env)
- [changelog/backlog/PDT-2026-03-26-026-sidebar-toggle-and-left-edge-inset.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/PDT-2026-03-26-026-sidebar-toggle-and-left-edge-inset.md)

## Verification

- `swift build`
- `swift test`
- Verified the release metadata was bumped for the shipped build

## Notes

- Kept the app-managed sidebar toggle path.
- Did not restore the old heavy sidebar controller behavior.
