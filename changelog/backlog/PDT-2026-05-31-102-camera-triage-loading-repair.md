# PDT-2026-05-31-102 camera triage loading repair

---
item_id: PDT-2026-05-31-102
title: Camera triage loading repair
status: closed_no_change
target_version: 0.2.57
target_build: 134
target_feature_slug: camera-triage-loading-repair
---

## User Request Summary

After installing `0.2.56`, Camera Triage shows `Current Session / Loading DCIM` in the sidebar while the main pane says `No source selected`. The user reports that triage is broken.

## Constraints

- Restore usable Camera Triage as the top priority.
- Preserve the readable date labels from `0.2.56`.
- Do not change archive folder names on disk.
- Keep source loading responsive and visible.
- Do not hide a loading or failed state behind `No source selected`.

## Implementation Intent

1. Reproduce or trace the `Loading DCIM` plus `No source selected` state.
2. Inspect launch/source-load state transitions and visible empty/loading UI.
3. Fix the state or UI path so Camera Triage either loads the source or shows the real loading/failure state.
4. Add focused regression coverage for the broken state.
5. Build, install, and launch a fixed app version.

## Test Conditions

- Source-workspace loading state renders as a loading/failure state, not as `No source selected`.
- Existing date-label navigation tests continue to pass.
- Focused Camera Triage/source loading tests pass.
- App bundle builds and installed metadata matches the target release.

## Success Criteria

- Camera Triage no longer presents contradictory `Loading DCIM` and `No source selected` states.
- If loading is still in progress, the main pane says that explicitly.
- If the source cannot load, the main pane surfaces the failure instead of looking idle.
- User can test `0.2.57` build `134`.

## Current Status

Closed without code changes after user confirmed Camera Triage loaded successfully and the apparent break was a slow source load.
