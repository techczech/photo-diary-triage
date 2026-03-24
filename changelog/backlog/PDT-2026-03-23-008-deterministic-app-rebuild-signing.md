# PDT-2026-03-23-008 Deterministic App Rebuild Signing

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.6`
- Target feature slug: `deterministic-app-rebuild`

## User Request

Make packaged app rebuilds deterministic so the app does not end up with a broken signature after a rebuild while a previous copy is running.

## Constraints

- Rebuilding the packaged app should not leave behind `PhotoDiaryTriage.cstemp` or stale signing artifacts.
- The packaged app should remain launchable after rebuilds performed during active development.
- This fix must preserve the version/footer workflow.

## Implementation Intent

- Stop the running packaged app before rebuilding.
- Recreate the bundle from a clean directory.
- Re-sign the final bundle only after the new executable, resources, and plist are in place.

## Test Conditions

- Rebuild while the previous packaged app is running.
- Verify `codesign -vvv dist/PhotoDiaryTriage.app` passes afterward.
- Verify the rebuilt packaged app launches normally.

## Success Criteria

- Rebuilds no longer produce stale `.cstemp` files or invalid seals.
- The packaged app remains launchable after rebuilds.
