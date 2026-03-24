# PDT-2026-03-23-009 Tracking Cleanup And Grouping Controls Report

## Summary

Normalized stale backlog spec statuses to match the append-only JSONL logs, corrected the recorded release mismatch on `PDT-2026-03-23-007`, and shipped adjustable grouping granularity as the next visible feature.

## Shipped Release

- Release version: `0.1.7`
- Feature slug: `grouping-granularity`

## What Changed

- Updated backlog specs `001`, `002`, `003`, `006`, `007`, and `008` so their markdown status matches the existing JSONL lifecycle state.
- Tightened and activated `PDT-2026-03-23-004` for the grouping-controls shipment.
- Corrected the `PDT-2026-03-23-007` report so it no longer collides with `PDT-2026-03-23-008` release metadata.
- Added settings-driven grouping threshold controls with in-place regrouping for active sessions.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/GroupingService.swift`
- `Sources/PhotoDiaryTriage/SettingsView.swift`
- `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift`
- `changelog/backlog/PDT-2026-03-23-001-release-versioning-and-ui-verification.md`
- `changelog/backlog/PDT-2026-03-23-002-default-ssd-auto-load.md`
- `changelog/backlog/PDT-2026-03-23-003-inline-collapsible-folder-sections.md`
- `changelog/backlog/PDT-2026-03-23-004-adjustable-grouping-granularity.md`
- `changelog/backlog/PDT-2026-03-23-006-app-bundle-codesign-fix.md`
- `changelog/backlog/PDT-2026-03-23-007-inline-sections-entrypoint-fix.md`
- `changelog/backlog/PDT-2026-03-23-008-deterministic-app-rebuild-signing.md`
- `changelog/backlog/PDT-2026-03-23-009-tracking-cleanup-and-grouping-controls.md`
- `changelog/changelog/PDT-2026-03-23-004-adjustable-grouping-granularity-report.md`
- `changelog/changelog/PDT-2026-03-23-007-inline-sections-entrypoint-fix-report.md`
- `changelog/changelog/PDT-2026-03-23-009-tracking-cleanup-and-grouping-controls-report.md`

## Verification

- `swift build` passed.
- compared backlog markdown status against `changelog/backlog.jsonl` for the normalized items.
- verified the `PDT-2026-03-23-007` report now records `0.1.5 / inline-sections-entrypoint-fix`.

## Known Gaps

- `swift test` was not runnable here because the local macOS CLT/XCTest install is incomplete.
- User review is still required for the newly shipped grouping controls and for the previously implemented items that remain in `awaiting_user_review`.
