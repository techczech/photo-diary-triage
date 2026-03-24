# PDT-2026-03-24-017 ContentView Decomposition Phase 1

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.18`
- Target feature slug: `contentview-decomposition-phase-1`

## User Request

Continue implementing the deferred-toolchain plan while full Xcode installs, using build-verifiable refactors that do not depend on `swift test`.

## Constraints

- Preserve existing UI behavior, keyboard handling, and modal behavior.
- Avoid changing view logic in ways that require broader automated test coverage before Xcode is available.
- Keep the extraction incremental and easy to verify with `swift build`.

## Implementation Intent

- Begin `ContentView` decomposition by extracting the obvious top-level panes and reusable sections into separate files.
- Move sidebar rendering, walk metadata editing, action buttons, footer status, and review pane composition out of `ContentView.swift`.
- Keep `ContentView` as the top-level coordinator with layout, hydration, and sheet/alert wiring.

## Test Conditions

- `swift build` succeeds after the extraction.
- The extracted subviews compile independently with `@ObservedObject AppState` bindings and existing callbacks.
- No modal, alert, or keyboard wiring is removed from the top-level view.

## Success Criteria

- `ContentView.swift` is materially smaller and easier to read.
- The extracted subviews are in separate files with clear, stable responsibilities.
