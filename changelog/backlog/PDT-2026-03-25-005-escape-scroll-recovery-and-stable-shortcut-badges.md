# PDT-2026-03-25-005 Escape Scroll Recovery And Stable Shortcut Badges

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.44`
- Target feature slug: `escape-scroll-recovery-and-stable-shortcut-badges`

## User Request

Escape from grouped drill-in still sometimes lands in a blank area that requires manual mouse scrolling, and extended use can crash the app. The hover tooltip work is not reliable enough to ship.

## Constraints

- Preserve the grouped Return and Cmd-Return behavior that already works in `0.1.43`.
- Fix the grouped Escape path and the crash without introducing new layout instability.
- Remove the crashy shortcut-hint presentation instead of trying to preserve it.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Make grouped-section scroll restoration explicit so returning from drill-in always forces a fresh scroll-to-section request even if the section ID did not change.
- Replace the crash-prone hover popover hint system with a stable always-visible shortcut-badge presentation on the key controls.
- Add regression coverage for grouped Escape returning to the full media set.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Escape from grouped drill-in returns to the full grouped view without leaving the user in a blank scrolled area.
- Repeated shortcut discovery interactions do not trigger the previous hover-popover crash path.

## Success Criteria

- Grouped Escape restores the correct grouped section and scroll position reliably.
- Shortcut hints remain discoverable without using a crash-prone hover system.
