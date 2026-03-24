# PDT-2026-03-24-033 Grouped Review Availability Control Fix

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.35`
- Target feature slug: `grouped-review-availability-control-fix`

## User Request

Clicking grouped review flickers back to flat review. The display control still offers grouped review in contexts where grouped review is unavailable, so the user can select an option that immediately falls back.

## Constraints

- Preserve the grouped-review shell visibility restored in `0.1.34`.
- Keep grouped review available on truly groupable contexts.
- Do not let the UI advertise a grouped mode that will immediately bounce back.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Make the display control reflect real grouped-review availability instead of always showing both modes.
- Keep the existing runtime guard in `AppState` as a safety net.
- Add regression coverage for the available display-mode list so unsupported contexts do not expose grouped review.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Non-groupable contexts expose only flat review.
- Groupable contexts still expose grouped review and can switch into it.

## Success Criteria

- Clicking grouped review no longer flickers back to flat review.
- The grouped option is shown only when it can actually work.
- Grouped review remains available in supported contexts.
