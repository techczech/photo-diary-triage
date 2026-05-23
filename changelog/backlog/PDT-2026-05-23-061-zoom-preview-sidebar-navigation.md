# PDT-2026-05-23-061: Zoom, Preview, And Sidebar Navigation

## User Request Summary

- Fix panning after zoom in compare mode.
- Make zoom/pan keyboard shortcuts work in single-photo preview.
- Make single-photo preview use as much screen space as possible.
- Auto-expand sidebar folders down to month level for easier navigation.

## Constraints

- Preserve keyboard-first triage.
- Keep compare and preview as direct inspection surfaces.
- Keep shortcut handling scoped to active preview or compare surfaces.
- Avoid broad visual redesign.
- Keep sidebar navigation fast and predictable.
- Keep backlog, changelog, and release metadata aligned.

## Implementation Intent

- Inspect existing zoom viewport and keyboard shortcut state.
- Share or mirror pan behavior between compare and single-photo preview where useful.
- Make preview image layout fill available screen while preserving aspect ratio.
- Expand archive/sidebar tree roots through year and month nodes by default.
- Add focused regression coverage for viewport panning and sidebar expansion defaults.

## Test Conditions

- Compare zoom can be panned with pointer and keyboard after zooming.
- Single-photo preview supports expected pan keyboard shortcuts after zooming.
- Single-photo preview image fills the available preview surface as much as aspect ratio allows.
- Sidebar archive folders initially expose month-level navigation.
- Existing review, preview, compare, and sidebar tests continue to pass.

## Success Criteria

- `APP_VERSION=0.2.22`.
- `APP_BUILD=99`.
- `APP_FEATURE_SLUG=zoom-preview-sidebar-navigation`.
- Zoomed compare and preview views can be navigated without mouse-only dead ends.
- Preview opens as a large inspection surface, not a small centered photo.
- Folder navigation starts expanded through month level.

## Current Status

- `approved_for_implementation`

## Target Release

- target version: `0.2.22`
- target build: `99`
- target feature slug: `zoom-preview-sidebar-navigation`
