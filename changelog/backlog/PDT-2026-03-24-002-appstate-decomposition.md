# PDT-2026-03-24-002 AppState Decomposition

## Status

- Current status: `draft`
- Priority: P0
- Target release version: TBD
- Target feature slug: `appstate-decomposition`

## User Request

Break the 1,589-line AppState god class into focused, testable sub-objects.

## Constraints

- Must preserve all existing reactive UI bindings (`@Published` properties).
- Must not regress any current functionality.
- Sub-objects must be independently testable.
- Dependency injection via protocols required for testability.

## Implementation Intent

- Extract `SessionManager` — session lifecycle: open, close, save, restore.
- Extract `BrowserViewModel` — sidebar tree building, archive inspection, node expansion.
- Extract `SelectionManager` — multi-pane selection coordination (sidebar, folder, media).
- Extract `ImportWorkflow` — import planning, execution, verification status.
- Define protocols for `FileScanning`, `SessionPersisting`, `MetadataExtracting`, etc.
- Keep `AppState` as a thin coordinator composing sub-objects via `@Published`.

## Test Conditions

- Each extracted sub-object has at least one unit test.
- `AppState` coordinator still drives the same UI behavior.
- No regressions in sidebar navigation, selection, import, or session persistence.

## Success Criteria

- `AppState.swift` reduced to <300 lines.
- Each sub-object is independently instantiable and testable.
- All existing app functionality preserved.
