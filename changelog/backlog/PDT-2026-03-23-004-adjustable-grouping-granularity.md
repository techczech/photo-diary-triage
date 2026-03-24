# PDT-2026-03-23-004 Adjustable Grouping Granularity

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.7`
- Target feature slug: `grouping-granularity`

## User Request

Make the grouping granularity adjustable.

## Constraints

- The app already has burst and proximity thresholds in settings.
- The adjustment controls need to be understandable in UI, not hidden in code.
- Changing granularity must not silently lose existing selections or review state without an explicit rule.

## Implementation Intent

- Expose user-facing controls for burst grouping and time-cluster grouping in Settings using the existing threshold settings.
- Persist threshold changes immediately and regroup the active session without forcing a re-scan from disk.
- Preserve media-item identity and keep the current sidebar node when it still exists after regrouping; otherwise fall back to the preferred initial node.
- Refresh inline day sections and other grouping-dependent browser state so the effect is visible immediately in the existing `Years -> Months -> Days` workflow.

## Test Conditions

- User can change burst-grouping and time-cluster thresholds from the Settings UI.
- Burst/time-cluster output changes consistently with the chosen thresholds.
- Grouping changes are reflected in the visible review/browser surfaces without losing stable media-item selection.
- Threshold changes persist across relaunch.

## Success Criteria

- The user can make grouping looser or tighter without leaving the app or editing config files.
- The currently open session updates in place and the release footer shows `v0.1.7 · grouping-granularity`.
