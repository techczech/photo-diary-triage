# PDT-2026-03-24-033 Grouped Review Availability Control Fix Report

## Summary Of What Changed

- Made the review display control reflect grouped-review availability instead of always showing both flat and grouped modes.
- Limited non-groupable contexts to the flat-review segment so the grouped option no longer flickers back after selection.
- Kept the grouped-mode fallback in `AppState` as a runtime safety net.
- Added regression coverage for supported and unsupported grouped-review display-mode availability.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog.jsonl`
- `changelog/backlog/PDT-2026-03-24-033-grouped-review-availability-control-fix.md`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- This only changes grouped-review option availability in the display control. It does not expand which node types support grouped review.

## Shipped Release

- Version: `0.1.35`
- Feature slug: `grouped-review-availability-control-fix`
