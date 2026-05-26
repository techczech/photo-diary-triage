# PDT-2026-05-26-075: Fresh app bundle build report

## Summary

- Fixed `scripts/build_app_bundle.sh` so it runs `swift build` before copying the executable into `dist/PhotoDiaryTriage.app`.
- Rebuilt and reinstalled `/Applications/PhotoDiaryTriage.app` from a freshly compiled executable.
- Added missing `@MainActor` annotations to crop-linked review card views so the current crop code compiles under this toolchain.
- Bumped release metadata to `APP_VERSION=0.2.33`, `APP_BUILD=110`, `APP_FEATURE_SLUG=fresh-app-bundle-build`.

## Files Changed

- `APP_RELEASE.env`
- `scripts/build_app_bundle.sh`
- `Sources/PhotoDiaryTriage/ContentReviewItemViews.swift`
- `changelog/backlog/PDT-2026-05-26-075-fresh-app-bundle-build.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `./scripts/build_app_bundle.sh`
  - Passed and performed a fresh `swift build`.
- `strings dist/PhotoDiaryTriage.app/Contents/MacOS/PhotoDiaryTriage`
  - Verified executable contains `Crop Visible`, `Drag Crop`, `Crop Focus`, and `Cropped`.
- Installed `/Applications/PhotoDiaryTriage.app`.
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app`
  - Passed.
- Checked installed metadata:
  - `CFBundleShortVersionString=0.2.33`
  - `CFBundleVersion=110`
  - `PDTLatestFeatureSlug=fresh-app-bundle-build`
- Verified installed executable contains crop UI strings.
- Launched `/Applications/PhotoDiaryTriage.app`; running PID was reported.

## Known Gaps Or Follow-Up Items

- `swift test --filter Crop` could not run on this machine because XCTest is unavailable under the active Command Line Tools developer directory.
- Manual crop UI verification is still needed in the running app.

## Shipped Release

- APP_VERSION: `0.2.33`
- APP_BUILD: `110`
- APP_FEATURE_SLUG: `fresh-app-bundle-build`
