# PDT-2026-05-22-052 Photo Log List Redesign

## Item ID

- PDT-2026-05-22-052

## Title

- Photo log list redesign

## User Request Summary

- The photo-log list still looks confusing and cramped after the inspector redesign.
- It needs the same modern, mac-native, task-focused redesign treatment as the workflow panel.

## Constraints

- Preserve existing log actions: continue, contents, edit log, details, and delete.
- Preserve membership locking rules.
- Preserve current-log state.
- Keep the list usable in the narrow inspector column.
- Avoid clipped titles and clipped button labels.
- Keep the design native macOS and compact.

## Implementation Intent

- Replace the old single-row photo-log layout with readable vertical log rows.
- Put each log's title, state, scope, counts, and path into predictable places.
- Use compact badges for log state and triage counts.
- Put primary actions first and move secondary actions into a stable wrapping grid.
- Show membership-lock messages without crushing the row.
- Add a cognitive-walkthrough note for the log-list interaction.

## Cognitive Walkthrough Questions

- Will the user recognise each log?
- Will the user notice whether it is current, copied, locked, or missing source?
- Will the user find the right action without reading all metadata?
- After choosing an action, will the row make the resulting state understandable?

## Test Conditions

- Full `swift test`.
- App bundle rebuild with `scripts/build_app_bundle.sh`.
- Launch rebuilt app and verify bundle release metadata.
- Visual/manual review of the inspector log-list layout.

## Success Criteria

- Log titles remain readable in the inspector.
- Actions no longer collapse into unreadable fragments.
- Current/copied/locked state is visible without parsing a long metadata line.
- Release version is bumped and handoff names the exact version to test.

## Current Status

- approved_for_implementation

## Target Release

- APP_VERSION: 0.2.13
- APP_BUILD: 90
- APP_FEATURE_SLUG: photo-log-list-redesign
