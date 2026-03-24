# PDT-2026-03-24-024 Grouping Test Baseline Fix

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.25`
- Target feature slug: `grouping-test-baseline-fix`

## User Request

Stabilize the post-Xcode test baseline now that `swift test` runs locally, starting with the current failing grouping-threshold test before broader test expansion work resumes.

## Constraints

- Keep the current `GroupingService.group(items:settings:)` behavior unless the failing test reveals a real semantic bug.
- Prefer updating stale test expectations over changing production grouping rules without a design-backed reason.
- Re-establish `swift build` and `swift test` as required local gates before more refactor work.

## Implementation Intent

- Investigate `groupingThresholdsChangeBurstAndClusterOutput()` against the actual contiguous-threshold grouping behavior.
- Correct the test so it asserts the intended burst and cluster semantics under tight and loose thresholds.
- Confirm the existing 7-test suite passes under the full Xcode environment.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- The grouping-threshold test verifies the actual threshold-sensitive change in cluster membership rather than a stale empty/non-empty expectation.

## Success Criteria

- The baseline local test suite is green under the new full-Xcode environment.
- The current grouping-threshold test aligns with actual intended grouping semantics.
- No production grouping code changes are made unless required by a documented product rule.
