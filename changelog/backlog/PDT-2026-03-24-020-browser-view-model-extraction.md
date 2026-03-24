# PDT-2026-03-24-020 Browser View Model Extraction

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.21`
- Target feature slug: `browser-view-model-extraction`

## User Request

Keep going on the refactor while Xcode installs by shrinking `AppState.swift` through another safe, build-verifiable extraction.

## Constraints

- Preserve current browser/sidebar/archive behavior.
- Keep published UI state in `AppState`; extract the pure browser construction and archive-loading logic.
- Avoid changing grouping or inline review behavior in this pass.

## Implementation Intent

- Extract browser tree construction, node mapping, preferred initial selection, and archive folder scanning into a dedicated browser view-model/helper object.
- Keep `AppState` responsible for state mutation, status messaging, and cache ownership.
- Replace direct browser-building methods in `AppState` with delegation to the new helper.

## Test Conditions

- `swift build` succeeds.
- Current-session and archive browser trees still compile and populate from the extracted helper.
- Archive folder loading still fills the cache and requests thumbnails when a leaf archive folder is selected.

## Success Criteria

- `AppState.swift` is materially smaller.
- Browser/archive concerns are isolated into a dedicated helper with clear inputs and outputs.
