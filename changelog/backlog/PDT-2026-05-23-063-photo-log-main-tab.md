# PDT-2026-05-23-063: Photo log main tab

## User Request Summary

- Move photo-log list and controls out of sidebar/side surfaces.
- Add a Photo Logs tab next to Camera Triage and Archive Triage.
- Put Create Photo Log in that tab.

## Constraints

- Keep Camera Triage and Archive Triage available as peer modes.
- Keep Create Photo Log tied to current source inbox decisions.
- Do not remove existing photo-log actions: continue, contents, details, edit log, add marked, delete.
- Avoid making the inspector a second photo-log library.
- Preserve keyboard/menu creation command.

## Implementation Intent

- Add Photo Logs as a main workspace mode.
- Render photo-log library as the main detail content in that mode.
- Remove the photo-log library disclosure from the inspector.
- Keep source-folder browser sidebar for archive/source navigation only.

## Test Conditions

- `swift test`
- Build app bundle with `./scripts/build_app_bundle.sh`

## Success Criteria

- Main mode selector includes Photo Logs beside existing triage modes.
- Photo Logs mode shows the log list and all per-log controls.
- Create Photo Log button is visible in Photo Logs mode.
- Inspector no longer contains photo-log library controls.
- Existing review and archive modes still compile and render through existing paths.

## Current Status

- status: approved_for_implementation
- target release version: `0.2.24`
- target feature slug: `photo-log-main-tab`
