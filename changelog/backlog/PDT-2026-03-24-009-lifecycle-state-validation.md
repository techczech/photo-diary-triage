# PDT-2026-03-24-009 Lifecycle State Validation

## Status

- Current status: `awaiting_user_review`
- Priority: P2
- Target release version: TBD
- Target feature slug: `lifecycle-state-validation`

## User Request

Enforce valid lifecycle state transitions so media items cannot jump to invalid states.

## Constraints

- Must not break existing import or cleanup workflows.
- Invalid transitions should produce descriptive errors, not silent no-ops.
- Transition graph: discovered → imported → verified → sourceCleanupPending → sourceCleaned.

## Implementation Intent

- Add `canTransition(to:)` method on `LifecycleState`.
- Define the valid transition graph as a static mapping.
- Add `transition(to:)` method that throws on invalid transitions.
- Update all call sites that mutate lifecycle state to use the validated method.

## Test Conditions

- Valid transitions succeed.
- Invalid transitions (e.g., discovered → sourceCleaned) throw with descriptive message.
- All existing workflows still complete successfully.

## Success Criteria

- No code path can set an invalid lifecycle state without an explicit error.

## Normalization Note

- Validated lifecycle transitions shipped as part of `PDT-2026-03-24-016` and are now covered by tests added in `PDT-2026-03-24-004`.
- This entry is no longer draft work; it is waiting only for user approval of the normalized backlog state.
