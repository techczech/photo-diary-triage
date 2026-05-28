# PDT-2026-05-27-081 crop links and gallery grouping

item_id: PDT-2026-05-27-081
title: Crop links and gallery grouping
status: approved_for_implementation
target_release_version: 0.2.37
target_feature_slug: crop-links-gallery-grouping

## User Request

Make original and cropped versions clearly linked, clickable, and adjacent in the app gallery.

## Constraints

- App navigation matters more than Finder reveal.
- Grid browsing must remain fast and non-overlapping.
- Selection must still work with mouse and keyboard.
- Crop family ordering must survive rescan and metadata differences.

## Implementation Intent

- Define crop family ordering: original first, crop versions after it.
- Keep crop families adjacent in review lists even if crop metadata is nil or differs.
- Move grid click hit-testing so crop link buttons are actually clickable.
- Add a clear in-card switch/open action for crop/original.
- Keep inspector crop version list as a secondary detailed view.

## Test Conditions

- Ordering test with original/crop dates equal.
- Ordering test with crop date nil or different.
- State test for opening crop from original and original from crop.
- Hit-test or interaction test proving card overlay does not swallow crop link controls.

## Success Criteria

- Original and crop versions appear next to each other.
- Original appears before crops.
- Clicking the link control changes preview/focus/selection to the linked version.
- Crop link controls work in grid, preview, compare, and inspector.
