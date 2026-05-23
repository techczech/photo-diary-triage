# PDT-2026-05-23-055: Source Log Membership Marks

## User Request Summary

When viewing the SD card/source browser, photos that have already been copied into or assigned to a photo log should have a visible mark next to them.

## Constraints

- Preserve the existing photo-log ownership and collision protection.
- Do not make copied/source-owned items look like ordinary undecided items.
- Keep the grid usable at a glance.
- The mark should appear in both grid and list review views.
- The source view should remain a faithful view of the SD card, not hide already-owned photos.

## Implementation Intent

- Keep source-scanned media visible in the inbox/source browser.
- Build a lightweight photo-log ownership lookup by source relative path.
- Add ownership metadata to `ReviewItemSnapshot`.
- Render a visible `In Log` or `Copied` badge on grid cards and list rows.
- Add tests for source visibility and ownership badge metadata.

## Test Conditions

- Opening or rebuilding a source inbox keeps files that are already owned by explicit photo logs visible.
- Matching source items receive a review snapshot badge naming the owning photo log.
- Unowned source items do not show the badge.
- Existing selection, creation, and import tests continue to pass.

## Success Criteria

- A user browsing the SD card can immediately see which visible photos already belong to a photo log.
- The mark is visible without opening the inspector.
- The change does not weaken duplicate-log collision protection.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.16
- APP_BUILD: 93
- APP_FEATURE_SLUG: source-log-membership-marks
