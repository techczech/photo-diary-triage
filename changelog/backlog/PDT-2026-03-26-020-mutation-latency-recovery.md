# PDT-2026-03-26-020 Mutation Latency Recovery

- Item ID: `PDT-2026-03-26-020`
- Title: `Mutation latency recovery`
- Current status: `approved_for_implementation`
- Target release version: `0.1.58`
- Target feature slug: `mutation-latency-recovery`

## User Request Summary

The first performance recovery pass improved some underlying image work, but the app still feels delayed after almost every action. The user reports a perceptible beat after interactions that used to feel instant.

## Constraints

- Keep the current design and interaction model intact.
- Do not add animations.
- Speed remains the overriding priority.
- Preserve correctness of session persistence and triage state updates.

## Implementation Intent

- Remove unnecessary derived-state rebuilds after routine triage mutations.
- Stop persisting the entire session synchronously on the main thread after every selection-state change.
- Keep session persistence reliable while making review actions feel immediate again.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - repeated `S` / `X` / `D` triage in large review grids
  - grouped/flat switching after repeated mutations
  - compare open/close after multiple triage changes

## Success Criteria

- The perceptible beat after routine review actions is substantially reduced.
- Selecting, excluding, clearing, and toggling RAW feel immediate again.
- Browser and grouped-review state remain correct after mutations.
- Session persistence still completes correctly.

