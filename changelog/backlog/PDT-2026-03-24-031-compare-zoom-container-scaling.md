# PDT-2026-03-24-031 Compare Zoom Container Scaling

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.33`
- Target feature slug: `compare-zoom-container-scaling`

## User Request

Grouped review and compare layout density now work, but zooming inside compare still changes only the image content and not the compare card containers. Compare zoom should scale the containers too, so zooming in and out changes the overall comparison surface rather than only the image inside a fixed frame.

## Constraints

- Preserve the new grouped review behavior from `0.1.32`.
- Keep the working compare layout-density controls.
- Do not regress compare fullscreen usage or multi-item layout.
- Release handoff must name the exact version to test and ask for testing.

## Implementation Intent

- Route compare zoom through both the compare grid metrics and the image canvas, so toolbar zoom affects container size as well as image presentation.
- Keep layout density controls as a separate baseline sizing input, then apply compare zoom on top of that baseline.
- Add regression coverage for compare zoom scaling the effective compare card width.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Compare zoom changes the size of the compare cards as well as the images.
- Compare layout controls still fit more items on screen independently of zoom.

## Success Criteria

- Compare zoom no longer feels like image-only zoom inside fixed cards.
- Compare remains usable for 3-4 items while supporting larger and smaller overall compare cards.
