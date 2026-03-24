# PDT-2026-03-24-012 CI Pipeline

## Status

- Current status: `draft`
- Priority: P2
- Target release version: TBD
- Target feature slug: `ci-pipeline`

## User Request

Add a GitHub Actions workflow for automated testing and build verification.

## Constraints

- Must run on macOS runner (Swift + SwiftUI + AppKit dependency).
- Must not require code signing secrets for basic CI.
- Should be fast enough to not block development (<5 min).

## Implementation Intent

- Create `.github/workflows/ci.yml`.
- Step 1: `swift test` — run all unit tests.
- Step 2: `swift build --configuration release` — verify release build compiles.
- Step 3 (optional): Run `scripts/build_app_bundle.sh` to verify bundle creation.
- Trigger on push to main and on pull requests.

## Test Conditions

- Workflow runs successfully on a clean macOS runner.
- Test failures cause the workflow to fail.
- Build failures cause the workflow to fail.

## Success Criteria

- Every push gets automated test and build verification.
