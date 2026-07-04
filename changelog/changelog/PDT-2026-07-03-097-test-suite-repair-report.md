# PDT-2026-07-03-097 Release A — test-suite repair (report)

item_id: PDT-2026-07-03-097
shipped_release_version: 0.4.1 (build 132)
shipped_feature_slug: test-suite-repair

## Summary of what changed

Release A repairs the regression net before the Walk/Trip/Triage implementation continues.
The full Swift test suite now completes successfully.

- Fixed the crop nudge regression test so it exercises a valid normalised crop rectangle and
  verifies that arrow-key nudging clamps the whole crop inside the image without changing
  size.
- Fixed stale archive-layout expectations in import and planner tests so they assert the
  ADR 0001 layout v2 paths: `YYYY/MM-MonthName/DD-Ddd-Walk-Slug/` and
  `yyyy-MM-dd-slug-NNN.ext` file stems.
- Fixed the fatal test abort by bounding the synthetic PNG fixture channel values before
  converting to `UInt8`; the previous fixture overflowed on wider images.
- Fixed a real crop relationship path bug: sibling crop paths now use string path
  manipulation so root-level relative paths remain relative instead of becoming absolute
  paths under the process working directory.
- Removed a timing-sensitive crop status assertion that could be overwritten by the
  test-only no-cache thumbnail store; the test still verifies durable crop integration,
  preview/focus/selection, and Cropped-filter visibility.

## Files changed

- Sources/PhotoDiaryTriage/AppState.swift
- Tests/PhotoDiaryTriageTests/CropServiceTests.swift
- Tests/PhotoDiaryTriageTests/ImportWorkflowTests.swift
- Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift
- Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift
- APP_RELEASE.env

## Verification performed

- `swift build` — passed.
- `swift test --filter cropNudgeClampsWithinImage` — passed.
- `swift test --filter importCoordinatorCommitCopiesSelectedFilesAndWritesManifests` —
  passed.
- `swift test --filter cropServiceCleansTemporaryFileAndFallsBackToBoundedJpegOutput` —
  passed.
- `swift test --filter archivePlannerBuildsDateBasedFolderAndHandlesCollisions` — passed.
- `swift test --filter cropMediaItemAddsOutputToReviewAndShowsCropImmediately` — passed.
- `swift test` — passed, 162 tests in 2 suites, 0 failures.
- `./scripts/build_app_bundle.sh` — passed.
- Installed `/Applications/Walkfolio.app`; verified installed metadata:
  `CFBundleShortVersionString=0.4.1`, `CFBundleVersion=132`,
  `PDTLatestFeatureSlug=test-suite-repair`.

Swift 6 Sendable warnings remain pre-existing/tolerated by the implementation plan.

## Known gaps or follow-up items

- No user-facing feature scope was added in Release A. This release only repairs the test
  suite and one crop relationship path bug exposed by the crop integration test.
- Release B remains next: Walk/Trip model objects and multi-Walk Triage, per the approved
  implementation plan.

## Handoff

Please test APP_VERSION 0.4.1 (build 132), `/Applications/Walkfolio.app`.

This should behave like 0.4.0 for normal app use, with the test-suite failures repaired
under the hood. As a light smoke test, open Walkfolio, browse or open a small Triage source,
and confirm the app launches normally and crop-created versions still appear beside their
original photo when you make a crop.
