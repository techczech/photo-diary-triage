# PDT-2026-03-24-022 Session Lifecycle Coordinator Extraction

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.23`
- Target feature slug: `session-lifecycle-coordinator-extraction`

## User Request

Push the refactor forward while full Xcode finishes installing by extracting the remaining session, persistence, and auto-load coordination logic out of `AppState.swift`.

## Constraints

- Preserve the SSD-first selective-import workflow in [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md).
- Keep `AppState` as the top-level `@MainActor` owner of published UI state and bindings.
- Do not change backup, recovery, or auto-load behavior beyond moving the logic behind a dedicated helper boundary.
- Keep this slice verifiable with `swift build`; do not depend on local `swift test` until full Xcode is available.

## Implementation Intent

- Extract persistence bootstrap, session open/restore/save, and default-source auto-load policy into a dedicated lifecycle helper.
- Leave `AppState` responsible for applying results to published properties, selection reset, and status messaging.
- Keep the existing `SessionManager`, `ImportWorkflow`, and browser helpers in place and compose the new helper around them.

## Test Conditions

- `swift build` succeeds.
- Startup persistence configuration still falls back gracefully when session or preview storage cannot be created.
- Opening a source folder, recovering the latest session, and mounted-default-source auto-load continue to compile through the extracted helper.

## Success Criteria

- `AppState.swift` is materially smaller again.
- Session bootstrap and auto-load policy live outside `AppState` behind a focused helper type.
- The shipped behavior for persistence recovery and default SSD auto-load remains unchanged.
