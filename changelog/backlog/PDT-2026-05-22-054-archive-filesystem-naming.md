# PDT-2026-05-22-054: Archive Filesystem Naming

## User Request Summary

The archive filesystem layout should match the original human-browsable plan. Current folders duplicate dates and copied files are not named with useful slugs. Month folders should look like `04 - April`, walk folders should look like `03-Monday-Birdwatch-walk`, and Markdown manifests should have the same basename as the walk folder and live in that same folder.

## Constraints

- Preserve copy safety and collision handling.
- Do not break existing import verification.
- Do not require cross-reference lookup when browsing in Finder.
- Keep archive names stable and human-readable.
- Keep date information at the folder level without duplicating it in nested folders.
- Preserve source filenames where needed for provenance in manifests.

## Implementation Intent

- Inspect current archive destination planning and manifest writing.
- Change month folder naming to `MM - Month`.
- Change walk folder naming to `DD-Weekday-title-slug`.
- Ensure copied photo destination filenames use readable slugs where the archive plan has enough metadata to name them safely.
- Write Markdown manifests into the walk folder using the same basename as the walk folder.
- Update tests to assert the exact folder and manifest names.

## Test Conditions

- A copied walk from April 3 creates an archive path containing `04 - April/03-Monday-Birdwatch-walk`.
- The Markdown manifest for that folder is `03-Monday-Birdwatch-walk.md` in the same folder.
- Copy verification and manifest rendering tests continue to pass.
- Collisions still produce unique folder or file paths without overwriting previous archive content.

## Success Criteria

- A human browsing the archive can understand a walk folder without opening app state.
- Manifest files are colocated with copied files and share the walk folder basename.
- The archive does not require a separate cross-reference folder to inspect what was copied.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.15
- APP_BUILD: 92
- APP_FEATURE_SLUG: archive-filesystem-naming
