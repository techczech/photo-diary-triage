# PDT-2026-03-24-021 Inline Section Organizer Extraction

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.22`
- Target feature slug: `inline-section-organizer-extraction`

## User Request

Keep reducing `AppState.swift` while full Xcode installs by extracting another pure, build-verifiable logic cluster.

## Constraints

- Preserve existing inline day/burst/cluster organization behavior.
- Keep current `AppState`-owned published state and view bindings unchanged.
- Limit this pass to extraction and delegation; do not redesign the grouping UX.

## Implementation Intent

- Extract inline section creation, remainder grouping, burst sampling, and preview ID selection into a dedicated helper.
- Replace the related `AppState` methods with calls into the new helper.
- Keep `AppState` responsible for selecting items and materializing `MediaItem` arrays for the views.

## Test Conditions

- `swift build` succeeds.
- Inline day sections, organized sections, and preview strip selection continue to compile and resolve through the new helper.
- Expand/collapse and preview selection still operate through the existing UI.

## Success Criteria

- `AppState.swift` is materially smaller again.
- Inline section organization is isolated into a helper with clear inputs and outputs.
