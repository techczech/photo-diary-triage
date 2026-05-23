# PDT-2026-05-23-060: global responsiveness speed

## User Request Summary

- Improve app speed significantly after `v0.2.20`.
- Switching tabs: instant.
- Opening sidebars: instant.
- Opening photos: significantly more responsive.
- Browsing folders: instant.
- Use Build macOS Apps practices.
- Test the running app with Computer.
- Ship as a different build from `v0.2.20`.

## Constraints

- Preserve current user-facing workflows.
- Prioritize speed and usability over refactor-only cleanup.
- Keep keyboard and mouse review behavior intact.
- Avoid broad visual redesign unless needed for responsiveness.
- Keep changelog, backlog, and release metadata aligned.

## Implementation Intent

- Analyze the current UI and image-loading paths before editing.
- Find slow synchronous work in tab/sidebar/folder/photo transitions.
- Move expensive image decode and preview work off immediate UI transitions where possible.
- Cache or reuse computed folder/sidebar/log status data where it affects navigation latency.
- Keep UI state changes small and immediate, then let heavier work complete asynchronously.

## Test Conditions

- Run unit tests.
- Build the macOS app bundle.
- Launch `dist/PhotoDiaryTriage.app`.
- Use Computer to exercise the live window where possible.
- Manually check tab switching, sidebar opening, photo opening, and folder browsing responsiveness.

## Success Criteria

- `APP_VERSION=0.2.21`.
- `APP_BUILD=98`.
- `APP_FEATURE_SLUG=global-responsiveness-speed`.
- Tab changes and sidebar toggles update the window immediately.
- Folder selection does not block on expensive preview/log/archive recalculation.
- Photo opening shows a responsive placeholder or cached content quickly while full image work continues.
- No regression in existing selection, preview, compare, or import tests.

## Current Status

- `approved_for_implementation`

## Target Release

- target version: `0.2.21`
- target build: `98`
- target feature slug: `global-responsiveness-speed`
