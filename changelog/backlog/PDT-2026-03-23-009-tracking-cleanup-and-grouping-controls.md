# PDT-2026-03-23-009 Tracking Cleanup And Grouping Controls

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.7`
- Target feature slug: `grouping-granularity`

## User Request

Implement the approved fix plan by first normalizing tracking state across backlog/changelog records and then shipping adjustable grouping granularity.

## Constraints

- Existing append-only JSONL history must not be rewritten.
- Tracking cleanup must make mismatches explicit rather than silently hiding them.
- Grouping controls must reuse the existing threshold settings and stay within the current design contract.
- The shipped app must keep the existing `Years -> Months -> Days` hierarchy and grid-first review flow.

## Implementation Intent

- Align stale backlog spec statuses with the latest JSONL state for already implemented items.
- Correct the recorded tracking mismatch for `PDT-2026-03-23-007`.
- Ship adjustable grouping controls as release `0.1.7` with feature slug `grouping-granularity`.
- Record both the tracking cleanup and the grouping feature in repo-native tracking files before presenting the change as complete.

## Test Conditions

- Backlog specs and JSONL logs agree on the current status of implemented items.
- The `PDT-2026-03-23-007` report no longer collides with `PDT-2026-03-23-008` release metadata.
- Settings exposes grouping controls and active sessions regroup immediately when thresholds change.
- The app footer shows the new release marker after shipping.

## Success Criteria

- Repo tracking is internally consistent for the touched items.
- Grouping granularity is adjustable from Settings and visible in the existing browser flow.
