# PDT-2026-05-22-054: Archive Filesystem Naming Report

## Summary

Archive copies now use the human-browsable folder and manifest layout:

- Year folder: `2023`
- Month folder: `04 - April`
- Walk folder: `03-Monday-Birdwatch-walk`
- Photo files: `03-Monday-Birdwatch-walk-001.jpg`
- Per-photo Markdown manifest: `03-Monday-Birdwatch-walk-001.md`
- Walk Markdown manifest: `03-Monday-Birdwatch-walk.md`

Markdown manifests are written directly beside the copied photos. The old `_session/WalkManifest.md` and `_session/files/<uuid>.md` layout is no longer used for new copies.

## Files Changed

- `Sources/PhotoDiaryTriage/ArchivePlanner.swift`
- `Sources/PhotoDiaryTriage/ImportCoordinator.swift`
- `Sources/PhotoDiaryTriage/Utilities.swift`
- `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift`
- `Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `APP_RELEASE.env`
- `changelog/backlog/PDT-2026-05-22-054-archive-filesystem-naming.md`

## Verification

- Ran focused archive planner test.
- Ran focused import-manifest placement test.
- Ran `swift test`; 102 tests passed.
- Built `dist/PhotoDiaryTriage.app`.
- Launched `dist/PhotoDiaryTriage.app`.
- Verified bundle metadata reports version `0.2.15` and build `92`.

## Known Gaps

- Existing archive folders already written with the older `_session` structure are not migrated in this release.
- New copies use the new layout.

## Shipped Release

- APP_VERSION: 0.2.15
- APP_BUILD: 92
- APP_FEATURE_SLUG: archive-filesystem-naming
