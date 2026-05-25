# PDT-2026-05-25-074 crop link filter and original safety

item_id: PDT-2026-05-25-074
title: Crop link filter and original safety
status: approved_for_implementation
target_release_version: 0.2.32
target_feature_slug: crop-link-filter-safety

## User Request

Add crop-aware browsing and safety.

User needs:

- filter by cropped images
- show original and crop together
- visual mark on any original that has crops
- visual mark on crop files
- click/preview the crop portion from the original
- from a crop, make it clear it is a crop and allow going back to original
- in archive browsing, crop should be primary
- prevent accidental cleanup/deletion of the original when a crop exists
- never end up with only the crop by accident

## UX Plan

- Add `Cropped` to the review filter menu.
- `Cropped` filter shows both:
  - original images that have at least one crop
  - crop images linked to an original manifest
- Original image badge:
  - `Has Crop`
  - click opens the newest crop preview when available.
- Crop image badge:
  - `Crop`
  - click opens the original preview when available.
- Archive normal browsing:
  - crop files sort before their originals within the same timestamp/name family.
  - crop badge stays visible so the crop is primary but not ambiguous.
- Safety:
  - source cleanup must not remove an original if a crop exists beside it.
  - item is treated as cleanup-locked until crops are moved/dealt with separately.

## Implementation Intent

- Use `<stem>.crops.json` as the durable crop relationship source.
- Extend scanned `MediaItem` with optional crop relationship metadata.
- Build crop relationship metadata during `FileScanner.scanFolder`.
- Add `.cropped` review filter.
- Add crop badges and linked preview actions to grid/list cards.
- Add AppState action to open linked crop/original preview.
- Exclude crop-linked originals from cleanup source deletion.
- Add tests for:
  - scanner marks original and crop relationship
  - cropped filter returns both original and crop
  - cleanup preserves original when crop exists

## Constraints

- Do not delete or mutate originals.
- Do not require a database migration for persisted sessions.
- Backward compatibility for sessions without crop metadata.
- Keep UI light; no modal management view in this pass.
- Keep original/crop link based on manifest and filenames/paths.
- Existing crop output may require reload to appear.

## Test Conditions

- `swift test --filter Crop`
- `swift test`
- `./scripts/build_app_bundle.sh`
- bundle metadata check
- app launch smoke check

## Success Criteria

- Cropped filter exposes original/crop pairs.
- Original and crop cards have visible relationship badges.
- Badges let user preview the paired file when available.
- Archive browsing prefers crop display order while still labelling crops.
- Source cleanup will not remove an original that has a crop manifest/output.
