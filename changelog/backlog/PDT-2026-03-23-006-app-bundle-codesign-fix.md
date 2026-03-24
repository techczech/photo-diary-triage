# PDT-2026-03-23-006 App Bundle Codesign Fix

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.4`
- Target feature slug: `bundle-codesign-fix`

## User Request

Fix the packaged app crash caused by invalid code signing so the rebuilt `.app` launches normally on macOS.

## Constraints

- The fix must apply to the packaged app bundle, not just the raw development executable.
- The build process must produce a launchable `.app` after every rebuild.
- The release version must increment and be visible in the app footer once the app launches.
- The tracking system must record the fix before it is presented as complete.

## Implementation Intent

- Update the app bundle build script to remove stale signatures and ad hoc sign the final bundle correctly.
- Ensure the executable, `Info.plist`, and resources are all included in the final bundle signature.
- Verify the bundle with `codesign` and a real launch attempt.

## Test Conditions

- `codesign -vvv dist/PhotoDiaryTriage.app` passes.
- The packaged app launches without `Taskgated Invalid Signature`.
- The launched app shows `v0.1.4 · bundle-codesign-fix`.

## Success Criteria

- The rebuilt `.app` is launchable from Finder or `open`.
- The crash report no longer shows `CODESIGNING 1 Taskgated Invalid Signature`.
