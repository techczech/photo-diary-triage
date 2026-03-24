# PDT-2026-03-24-025 Instruction Cleanup And Backlog Normalization Report

## Summary Of What Changed

- Rewrote the root [AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/AGENTS.md) into a short guardrail file focused on backlog/changelog accuracy, usability-first priorities, and where detailed instructions live.
- Added nested app and test instruction files at [Sources/PhotoDiaryTriage/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AGENTS.md) and [Tests/PhotoDiaryTriageTests/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/AGENTS.md).
- Normalized stale backlog items `001`, `003`, `005`, `006`, `009`, and `010` so their status matches the code and changelog reality instead of remaining blocked or draft.
- Excluded the nested AGENTS files from SwiftPM targets in [Package.swift](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Package.swift) so the new instruction files do not show up as unhandled target inputs.

## Files Changed

- `AGENTS.md`
- `Package.swift`
- `Sources/PhotoDiaryTriage/AGENTS.md`
- `Tests/PhotoDiaryTriageTests/AGENTS.md`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-001-testing-module-bootstrap.md`
- `changelog/backlog/PDT-2026-03-24-003-error-handling-hardening.md`
- `changelog/backlog/PDT-2026-03-24-005-contentview-decomposition.md`
- `changelog/backlog/PDT-2026-03-24-006-silent-failure-logging.md`
- `changelog/backlog/PDT-2026-03-24-009-lifecycle-state-validation.md`
- `changelog/backlog/PDT-2026-03-24-010-import-progress-reporting.md`
- `changelog/backlog/PDT-2026-03-24-025-instruction-cleanup-and-backlog-normalization.md`
- `changelog/backlog/PDT-2026-03-24-026-review-interaction-rescue.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- The actual review usability rescue ships separately under `PDT-2026-03-24-026`.
- The normalized backlog entries are still `awaiting_user_review` until the user explicitly approves them.

## Shipped Release

- Version: `0.1.27`
- Feature slug: `instruction-cleanup-backlog-normalization`
