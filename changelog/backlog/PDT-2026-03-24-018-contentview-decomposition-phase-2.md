# PDT-2026-03-24-018 ContentView Decomposition Phase 2

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.19`
- Target feature slug: `contentview-decomposition-phase-2`

## User Request

Continue the refactor while Xcode installs by pushing `ContentView` closer to a coordinator-only role.

## Constraints

- Preserve existing browsing, review, and keyboard behavior.
- Keep the extraction build-verifiable with `swift build`.
- Reuse the support views already moved out in phase 1.

## Implementation Intent

- Extract the header pane, inline-day browser, folder browser, review pane, and browser/review switching logic into a separate file.
- Keep modal, sheet, alert, and form-hydration logic in `ContentView.swift`.
- Reduce the remaining top-level file to layout orchestration and state hydration.

## Test Conditions

- `swift build` succeeds.
- The extracted browser/review sections compile and still bind correctly to `AppState`.
- Keyboard focus and compare/open/import actions remain wired through the same `AppState` methods.

## Success Criteria

- `ContentView.swift` is reduced to a coordinator-scale file.
- The browser/review composition is isolated in separate reusable view types.
