# PDT-2026-05-27-076 crop implementation audit

item_id: PDT-2026-05-27-076
title: Crop implementation audit
status: active_audit
target_release_version: analysis-only
target_feature_slug: crop-implementation-audit

## User Request

Audit the crop feature against the initial plan.

User reports:

- crop badge is visible
- cropped images are not visible
- prior crop work feels incomplete

## Constraints

- Do not implement fixes in this pass unless separately requested.
- Check original crop plan and follow-up crop safety plan.
- Inspect tracking, code paths, and tests.
- Report each individual planned feature as implemented, partial, or missing.
- Surface mismatches between tracking reports and actual code.

## Implementation Intent

- Read crop backlog specs and reports.
- Trace crop service, preview crop UI, compare crop UI, scanner crop relationships, filter, badge links, sorting, cleanup safety, and tests.
- Identify why crop outputs may be saved but not visible in current grids.
- Give user a concrete repair list.

## Test Conditions

- Static code trace to concrete files and symbols.
- Run focused tests if needed to verify service/filter behavior.

## Success Criteria

- User can see which crop-plan features exist, which are partial, and which are missing.
- Missing work is specific enough to become an implementation checklist.

## Audit Findings

### Summary

- Crop engine exists and writes files plus manifests.
- Preview and compare controls exist.
- Crop relationship badge can appear immediately after saving a crop.
- New crop file is not added to the active `MediaItem` list after crop save.
- Crop preview/link/filter therefore only fully works after a folder/session rescan loads the crop file.
- This matches the user report: badge visible, cropped images absent.

### Implemented

- `CropService` writes non-destructive sibling crop files.
- Unique filenames use `-cropped`, then numbered suffixes.
- Manifest appends crop entries in `<stem>.crops.json`.
- Preview sheet has `Crop Visible`, `Drag Crop`, and `V`.
- Compare sheet has `Crop Focus`, per-card crop button, `Drag Crop`, and `V`.
- `FileScanner` can read crop manifests and mark original/crop relationships when both files are scanned.
- `Cropped` filter exists.
- Crop/original badges exist in grid, list, preview, and compare.
- Cleanup skips original source deletion when an original has crop outputs recorded.

### Partial Or Missing

- Missing: automatic insertion/rescan of the new crop as a `MediaItem` after crop save.
- Missing: automatic refresh of current grid/list/archive cache after crop output appears.
- Partial: badge click opens linked crop/original only if the linked item is already loaded.
- Partial: `Cropped` filter shows the original immediately, but not the new crop until rescan.
- Partial: archive crop-primary sorting works only after archive cache reload/rescan.
- Partial: "preview crop portion from original" is implemented as "open latest crop file", not as an in-place crop-region preview.
- Missing: crop history inspector.
- Missing: reveal linked crop/original in Finder.
- Missing: dedicated crop-pair compare view.
- Missing: rotated-image/manual pointer verification.
- Missing: test for the actual failure mode: crop save should make the new crop visible without manual reload.

### Repair Checklist

- After `CropService.crop`, create/load a `MediaItem` for the output crop file.
- Add it to current session or archive cache as appropriate.
- Add crop relationship to both original and new crop item.
- Rebuild browser/review caches when the item list changes.
- Preserve selection/focus and optionally focus or preview the new crop.
- Invalidate archive cache for the affected folder after archive crop save.
- Add regression tests for immediate grid visibility, cropped filter membership, and badge link navigation without manual rescan.
