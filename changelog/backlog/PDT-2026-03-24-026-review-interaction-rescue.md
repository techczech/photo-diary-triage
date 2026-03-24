# PDT-2026-03-24-026 Review Interaction Rescue

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.28`
- Target feature slug: `review-interaction-rescue`

## User Request

Rescue the core review workflow so the app is actually usable: reliable selection, correct keyboard navigation and shortcut scope, non-overlapping review cards, zoomable previews, and compare flows that support real import decisions.

## Constraints

- Grid review remains the primary review surface.
- Selection must follow standard macOS plain-click, Shift-click, and Command-click semantics.
- Keyboard review commands must be scoped to the active review surface and must not fire from forms, sheets, or unrelated controls.
- Performance work should prioritize visible thumbnails and responsive navigation before deeper refactors.

## Implementation Intent

- Replace review-grid tap gestures with an AppKit-backed click target that preserves modifier flags and double-click behavior.
- Use measured review-grid geometry for keyboard up/down navigation instead of screen-width guesses.
- Add persistent review-card sizing and fixed card spacing with subtle base borders.
- Upgrade preview and compare flows so they support navigation and direct mark/unmark actions.
- Add regression coverage for selection, focus gating, preview/compare state, and review-grid navigation.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds with added selection/navigation/preview/compare coverage.
- Manual verification confirms mouse selection, keyboard selection, preview, compare, and grid layout all work in the main review flow.

## Success Criteria

- Review selection works correctly with both mouse and keyboard.
- Grid cards remain separated and legible at supported window widths.
- Preview and compare are usable decision tools instead of passive viewers.
- The app is materially closer to real-world triage speed and ergonomics.
