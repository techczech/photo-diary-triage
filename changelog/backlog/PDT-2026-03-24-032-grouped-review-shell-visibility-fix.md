# PDT-2026-03-24-032 Grouped Review Shell Visibility Fix

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.34`
- Target feature slug: `grouped-review-shell-visibility-fix`

## User Request

Grouped view disappeared. After the recent compare and review changes, the user can no longer reach grouped review in contexts where they still expect the grouped review shell and controls to remain available.

## Constraints

- Preserve the working flat review, compare, and zoom behavior from `0.1.33`.
- Do not hide the review shell just because the current node lacks inline day sections.
- Keep grouped review unavailable only when the current selection genuinely cannot support grouped organization.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Restore a consistent review shell for all media-review contexts by routing media review through the same day-context host view.
- Guard grouped review mode so selecting it falls back cleanly when the current node has no groupable inline sections.
- Add regression coverage for the grouped-review availability logic so the shell does not disappear again.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Review contexts with visible media still show the grouped/flat review shell.
- Grouped review is selectable when inline day sections exist and falls back safely when they do not.

## Success Criteria

- Grouped view no longer disappears unexpectedly while browsing reviewable media.
- The user can consistently find the review display controls from the same place.
- Unsupported contexts fail gracefully instead of silently hiding the feature.
