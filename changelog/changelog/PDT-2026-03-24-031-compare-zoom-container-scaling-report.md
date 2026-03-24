# PDT-2026-03-24-031 Compare Zoom Container Scaling Report

## Summary Of What Changed

- Routed compare zoom into the compare grid metrics instead of leaving zoom image-only.
- Made compare zoom change the effective compare card target width, so zooming now scales the compare containers as well as the image content.
- Preserved the separate compare layout-density controls so baseline “fit more items” behavior still works independently of zoom.
- Added regression coverage for compare zoom affecting compare card width.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ReviewInteractionSupport.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-031-compare-zoom-container-scaling.md`

## Verification Performed

- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- This only adjusts compare zoom behavior; it does not change the grouped review or flat review sizing paths.

## Shipped Release

- Version: `0.1.33`
- Feature slug: `compare-zoom-container-scaling`
