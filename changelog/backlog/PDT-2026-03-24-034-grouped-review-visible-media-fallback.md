# PDT-2026-03-24-034 Grouped Review Visible Media Fallback

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.36`
- Target feature slug: `grouped-review-visible-media-fallback`

## User Request

Grouped review is not even visible now. The user expects grouped review to be available while reviewing actual media, not only when the browser tree happens to expose day nodes directly.

## Constraints

- Preserve the review-shell visibility restored in `0.1.34`.
- Preserve the display-control availability logic from `0.1.35`, but expand grouped-review support so it is available in normal review contexts with visible media.
- Do not regress flat review, compare, or keyboard-driven review behavior.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Synthesize grouped-review day sections from the current visible media set when the selected browser node does not already provide inline day sections.
- Derive day, burst, and cluster section structure from `MediaItem.capturedAt`, `burstGroupID`, and `timeClusterID`.
- Keep grouped review unavailable only when there is no visible review set to organize.
- Add regression coverage for grouped review availability on leaf review contexts.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Leaf review contexts with visible media expose grouped review.
- Grouped review still works on browser nodes that already expose day sections.
- Empty/non-review contexts still do not expose grouped review.

## Success Criteria

- Grouped review is visible in normal review contexts again.
- Grouped review organizes the currently visible media even when the browser tree is not positioned on a day container.
- The display control reflects actual review capability instead of browser-node shape.
