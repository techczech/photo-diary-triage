# PDT-2026-05-25-073 quick non-destructive crop report

item_id: PDT-2026-05-25-073
status: implemented
shipped_release_version: 0.2.31
shipped_feature_slug: quick-nondestructive-crop

## Summary

Implemented a lightweight non-destructive crop feature for preview and compare workflows.

User-visible behavior in `APP_VERSION=0.2.31`:

- preview sheet has `Crop Visible` and `Drag Crop`
- compare sheet has `Crop Focus`, `Drag Crop`, and per-card crop buttons
- `V` crops the visible zoomed area in preview or compare
- crop output saves beside the original file
- output names use `-cropped`, then `-cropped-2`, `-cropped-3`, and so on
- source JPEG/HEIC/PNG/TIFF outputs stay in the same family where supported
- RAW or unsupported source crops render as high-quality TIFF copies
- original file is never modified or removed
- manifest saves beside the original as `<stem>.crops.json`
- manifest appends each crop with trigger, output path, normalized rect, pixel rect, output dimensions, and release metadata

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppRelease.swift`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/CropService.swift`
- `Tests/PhotoDiaryTriageTests/CropServiceTests.swift`
- `changelog/backlog/PDT-2026-05-25-073-quick-nondestructive-crop.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification

- `swift build`: passed
- `swift test --filter CropService`: passed, 2 Swift Testing tests
- `swift test`: passed, 130 Swift Testing tests
- `./scripts/build_app_bundle.sh`: built `dist/PhotoDiaryTriage.app`
- bundle metadata checked:
  - `CFBundleShortVersionString`: `0.2.31`
  - `CFBundleVersion`: `108`
  - `PDTLatestFeatureSlug`: `quick-nondestructive-crop`
- launched `dist/PhotoDiaryTriage.app` for smoke check

## Known Gaps

- manual drag crop has service coverage and compile coverage, but still needs real-photo hands-on testing for pointer feel and vertical crop alignment on rotated images
- crop outputs are written to disk and manifest immediately, but the current browser view may need a reload to show the new crop file in the grid
- RAW crops are rendered copy outputs, not RAW edits
- metadata preservation is best-effort through Image I/O; manifest is the authoritative crop provenance

## Follow-Up Candidates

- add automatic grid refresh after crop output appears
- add optional crop preview before saving
- add crop history browser from the inspector
- add checksum or pixel hash into crop manifest
- add rotated-image fixture tests
