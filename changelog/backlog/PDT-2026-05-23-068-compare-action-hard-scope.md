# PDT-2026-05-23-068: compare action hard scope

## User Request Summary

- Previous compare fix failed.
- Cmd-A in compare followed by exclude could exclude photos outside the compare set.
- Compare view actions must only affect photos currently in compare.
- Highest priority: reset, retest, and cover edge cases.

## Constraints

- Treat compare as a hard action boundary in state, not only in view focus.
- S/C/X/D/RAW while compare is open must never mutate outside `comparingMediaItemIDs`.
- Cmd-A and Deselect while compare is open must never select or clear outside compare.
- Preserve existing review grid and full preview behavior when compare is closed.
- Update release metadata, backlog, changelog, tests, app bundle.

## Implementation Intent

- Clamp current action scope to compare IDs whenever compare is open.
- Route generic current-selection triage commands through compare-safe selection scope.
- Make select-all, deselect, clear, and RAW actions compare-safe even if invoked from menu commands.
- Add regression tests that simulate stale/full-folder selection while compare is open, then exclude/include/candidate/clear/RAW.

## Test Conditions

- Regression: stale included photos outside compare remain included after compare Cmd-A + exclude.
- Regression: generic menu-style S/C/X/D actions while compare open mutate only compare IDs.
- Regression: select all and clear current selection while compare open affect only compare IDs.
- Regression: RAW toggle while compare open targets compare-scoped selected IDs only.
- Full Swift test suite passes.

## Success Criteria

- Compare mode enforces its own action boundary from `AppState`.
- Tests prove outside-compare photos are not mutated by compare actions.
- `APP_RELEASE.env` ships new version.

## Current Status

- status: approved_for_implementation

## Target Release

- APP_VERSION: 0.2.28
- APP_BUILD: 105
- APP_FEATURE_SLUG: compare-action-hard-scope
