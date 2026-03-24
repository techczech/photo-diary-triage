# PDT-2026-03-23-001 Release Versioning And UI Verification

## Status

- Current status: `approved_done`
- Target release version: `0.1.1`
- Target feature slug: `release-versioning-ui`

## User Request

Strengthen the workflow so every change has an explicit version increment and a visible in-app version marker, then implement the first two visible app changes under that system using subagents.

## Constraints

- Work must follow the repo-native tracking workflow under `/changelog/`.
- Every implemented change must increment the app version.
- The app must show the current version and a short slug for the most recently implemented feature in the bottom-left corner so the user can verify they are seeing the correct build.
- The first visible app changes must be obvious enough that the user can confirm they landed.
- Subagents must be used for implementation.

## Implementation Intent

1. Harden the tracking instructions so version bumps are mandatory for implemented work.
2. Add a single source of truth for release metadata used by both the app and the packaged `.app` bundle.
3. Show the current release version and latest-feature slug in the bottom-left footer of the app.
4. Re-implement the first two visible UI cleanup items in a clearly testable way:
   - remove the whole-review blue focus ring
   - replace the orange/ambiguous selection styling with an unmistakable whole-card selection treatment

## Test Conditions

- Tracking instructions explicitly require a version bump and release marker for each implemented change.
- The packaged app bundle exposes the new version/build metadata.
- The running app shows version plus latest-feature slug in the bottom-left corner.
- The whole-review blue focus ring is gone.
- Selected cards have a clear full-card selection outline with no orange focus line.
- The version marker changes when the release metadata is incremented.

## Success Criteria

- The user can visually confirm they are testing the intended build from the app window itself.
- Future implementation work cannot be presented as complete without a release/version update.
- The first two UI cleanup items are visibly present and easy to verify.
