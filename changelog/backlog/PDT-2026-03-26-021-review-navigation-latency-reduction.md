# PDT-2026-03-26-021 Review Navigation Latency Reduction

- Item ID: `PDT-2026-03-26-021`
- Title: `Review navigation latency reduction`
- Current status: `approved_for_implementation`
- Target release version: `0.1.59`
- Target feature slug: `review-navigation-latency-reduction`

## User Request Summary

Even after the broader performance fixes, arrow-key navigation in review still feels delayed. The user reports roughly half a second between photo changes, with noticeably worse lag when scrolling is involved.

## Constraints

- Preserve the current grid and grouped-review behavior.
- Do not add animations.
- Keyboard navigation speed is a product-critical path.

## Implementation Intent

- Investigate the review focus and scroll path for per-arrow expensive work.
- Stop scrolling the review surface on every focus change.
- Make scroll requests only when the focused item moves outside the currently visible page.
- Keep grouped review and list behavior correct while reducing grid navigation latency.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - repeated arrow-key movement in flat review
  - repeated arrow-key movement in grouped review item navigation
  - navigation across page boundaries where scrolling is required

## Success Criteria

- Arrow-key focus changes feel immediate when the next item is already visible.
- Scroll-induced navigation delay is materially reduced because scroll happens less often.
- Focus, selection, and grouped-review behavior remain correct.

