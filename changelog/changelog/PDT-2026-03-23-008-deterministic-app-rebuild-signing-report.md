# PDT-2026-03-23-008 Deterministic App Rebuild Signing Report

## Summary Of What Changed

- Fixed the packaged app rebuild path so rebuilding while iterating no longer leaves the bundle in a broken signed state.
- The build script now stops the running packaged app, recreates the app bundle from a clean directory, clears extended attributes, and signs the finished bundle with the working ad hoc signing sequence.

## Files Changed

- `APP_RELEASE.env`
- `scripts/build_app_bundle.sh`

## Verification Performed

- `swift build`
- `zsh -x scripts/build_app_bundle.sh`
- `codesign -vvv dist/PhotoDiaryTriage.app`
- launched the packaged app with `open`
- verified the launched process came from the packaged bundle

## Known Gaps Or Follow-Up Items

- This fix still needs user approval after confirming rebuilds remain stable in use.

## Shipped Release

- Version: `0.1.6`
- Feature slug: `deterministic-app-rebuild`
