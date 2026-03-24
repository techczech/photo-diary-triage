# PDT-2026-03-24-005 ContentView Decomposition

## Status

- Current status: `partially_implemented_via_follow_on_items`
- Priority: P1
- Target release version: TBD
- Target feature slug: `contentview-decomposition`

## User Request

Extract the 1,452-line ContentView into focused sub-views in separate files.

## Constraints

- Must preserve all existing layout, keyboard handling, and modal behavior.
- Sub-views should receive state via `@ObservedObject` or `@EnvironmentObject`.
- Must not break DESIGN.md rules (grid-first, keyboard parity, closable modals).

## Implementation Intent

- Extract `SidebarView` — navigation tree rendering.
- Extract `MediaGridView` — photo grid with selection handling.
- Extract `InspectorPanelView` — right-hand details panel.
- Extract `WalkMetadataForm` — walk title/location/notes editing.
- Extract `ImportProgressSheet` — import workflow UI.
- Keep `ContentView` as the layout coordinator (~200 lines).

## Test Conditions

- All existing UI behavior preserved after extraction.
- Each sub-view compiles independently with its required state bindings.

## Success Criteria

- `ContentView.swift` reduced to <300 lines.
- Each sub-view is in its own file with clear responsibility.

## Normalization Note

- The practical decomposition work landed through `PDT-2026-03-24-017`, `018`, and `019`.
- `ContentView.swift` is already reduced to a coordinator-sized file, but some extraction goals were superseded by the current usability-first review rescue.
- Remaining UI cleanup should be tracked through usability-focused backlog items rather than more decomposition-only work.
