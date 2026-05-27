# PDT-2026-05-27-078 crop history and version switching

item_id: PDT-2026-05-27-078
title: Crop history and version switching
status: awaiting_user_review
target_release_version: 0.2.35
target_feature_slug: crop-history-version-switching

## User Request

Implement crop history and in-app switching.

User wants:

- crop history inspector
- primary ability to link and switch between original and cropped versions inside the app
- Finder reveal is less important and can wait
- support more than one crop for one original

## Constraints

- Keep original and crops non-destructive.
- Use loaded crop relationships and manifests already scanned/created.
- Do not make Finder the primary path.
- Keep UI compact and inspector-native.
- Update `APP_RELEASE.env`.
- Create changelog report and JSONL updates after implementation.

## Implementation Intent

- Add crop history data to inspector state.
- Build versions from `CropRelationship`: original first, then all crop outputs.
- Show crop version list in Selected Photo inspector.
- Mark current version.
- Let user open any loaded original/crop version from the inspector.
- Keep badge latest-crop behavior unchanged.

## Test Conditions

- Build app.
- Add focused state test for inspector crop versions and in-app switching.
- Build app bundle for `APP_VERSION=0.2.35`.

## Success Criteria

- Selecting an original with crops shows original plus all crops.
- Selecting a crop shows original plus sibling crops.
- Current version is clearly marked.
- Clicking a loaded crop/original switches preview/focus/selection inside the app.
- Finder is not required for crop switching.

## Implementation Notes

- Inspector now shows `Crop Versions` for originals and crop outputs.
- Version list puts the original first, then all known crop outputs.
- Current version is marked visually.
- Loaded versions can be opened inside the app from the inspector.
- Unloaded versions are shown as `Not loaded` and cannot be opened until present in the current browser view.
