# PDT-2026-05-22-049 Photo Log Edit Semantics

## Item ID

- PDT-2026-05-22-049

## Title

- Photo log edit semantics

## User Request Summary

- User clarified that editing a log means changing photo membership and S/C/X status.
- Metadata changes such as title, notes, and scope should not be presented as the main log-edit action.

## Constraints

- Preserve selection mechanics.
- Preserve existing membership-edit implementation.
- Preserve metadata editing, but rename it clearly as details-only.
- Keep RAW companion work out of scope.
- Keep release and tracking records aligned.

## Implementation Intent

- Rename the photo-log library membership action from `Edit Items` to `Edit Log`.
- Rename metadata-only actions and surfaces to `Details` / `Log Details` rather than `Edit Log`.
- Update status, help text, and sheet copy so `Edit Log` means changing S/C/X status and adding/removing photos from the log.
- Add wording regression tests for the new semantic contract.

## Test Conditions

- Unit tests for photo-log action wording constants.
- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.
- Launch rebuilt app and verify bundle release metadata.

## Success Criteria

- User sees `Edit Log` as the path for changing log membership and S/C/X status.
- User sees details-only editing as title/notes/scope metadata, not the main log edit.
- No selection behavior changes.
- Release version is bumped and handoff names exact version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.10
- APP_BUILD: 87
- APP_FEATURE_SLUG: photo-log-edit-semantics
