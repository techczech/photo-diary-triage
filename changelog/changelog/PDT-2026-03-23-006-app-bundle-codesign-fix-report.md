# PDT-2026-03-23-006 App Bundle Codesign Fix Report

## Summary Of What Changed

- Fixed the packaged app crash caused by an invalid bundle signature.
- Updated the app bundle build script to rebuild the bundle with a valid ad hoc signature after copying the executable, resources, and `Info.plist`.
- Bumped the shipped release to `0.1.4` with feature slug `bundle-codesign-fix`.

## Files Changed

- `APP_RELEASE.env`
- `scripts/build_app_bundle.sh`

## Verification Performed

- `bash scripts/build_app_bundle.sh`
- `codesign -vvv dist/PhotoDiaryTriage.app`
- `codesign -dv --verbose=4 dist/PhotoDiaryTriage.app`
- `open /Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/dist/PhotoDiaryTriage.app`
- verified the launched process came from the packaged app bundle

## Known Gaps Or Follow-Up Items

- This hotfix still needs user approval after confirming the rebuilt app launches normally.

## Shipped Release

- Version: `0.1.4`
- Feature slug: `bundle-codesign-fix`
