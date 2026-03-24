# PDT-2026-03-24-023 Session Mutation Coordinator Extraction

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.24`
- Target feature slug: `session-mutation-coordinator-extraction`

## User Request

Keep pushing the refactor forward while full Xcode installs by extracting another coherent session-management block out of `AppState.swift`.

## Constraints

- Preserve existing import-selection, backup-confirmation, and walk-metadata behavior.
- Keep lifecycle transitions validated and logged when invalid transitions are attempted.
- Keep `AppState` responsible for published UI state and status messaging.
- Stay within build-verifiable changes that can be checked with `swift build`.

## Implementation Intent

- Extract session mutation rules into a dedicated helper that owns metadata edits, RAW companion toggles, import-selection transitions, and backup-confirmation state updates.
- Leave `AppState` as the orchestration layer that decides when to save and what status message to show.
- Reduce direct mutation of `ImportSession` arrays inside `AppState`.

## Test Conditions

- `swift build` succeeds.
- Walk metadata edits, RAW companion toggles, and import selection changes still compile through the extracted helper.
- Backup confirmation still advances verified items to cleanup-pending without changing the SSD-first safety flow.

## Success Criteria

- `AppState.swift` is materially smaller again.
- Session mutation rules are isolated into a focused helper with explicit inputs and outputs.
- Lifecycle-transition logging behavior remains intact after the extraction.
