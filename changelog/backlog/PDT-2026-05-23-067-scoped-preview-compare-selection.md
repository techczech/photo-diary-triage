# PDT-2026-05-23-067: scoped preview and compare selection

## User Request Summary

- Fix Cmd-A in compare view selecting folder items instead of compare items.
- Add a way to select/include and exclude from the full image view.

## Constraints

- Keep shortcuts scoped to active review surface.
- Preserve compare as a secondary surface launched from current review context.
- Preserve source/archive mutation locks.
- Do not disturb existing uncommitted log-session work.

## Implementation Intent

- Add compare-scoped select-all/deselect behavior.
- Wire compare Cmd-A / Cmd-Shift-A to compare item IDs only.
- Add full-photo S/C/X/D/RAW controls and keyboard shortcuts.
- Use existing AppState triage mutation paths and lifecycle locks.

## Test Conditions

- Regression: compare select-all selects only compare items.
- Regression: full-photo triage actions mutate the previewed item.
- Run focused Swift tests for review interactions.

## Success Criteria

- Cmd-A in compare selects only images currently in compare.
- Cmd-Shift-A in compare clears only current compare selection.
- Full image view can mark previewed photo S, C, X, D and toggle RAW where available.
- `APP_RELEASE.env` increments for this shipped change.

## Current Status

- status: approved_for_implementation

## Target Release

- APP_VERSION: 0.2.27
- APP_BUILD: 104
- APP_FEATURE_SLUG: scoped-preview-compare-selection
