# PDT-2026-07-03-097 toolbar/header cleanup from 0.3.0 feedback (report)

item_id: PDT-2026-07-03-097
shipped_release_version: 0.3.1 (build 130)
shipped_feature_slug: toolbar-header-cleanup

## Summary of what changed

Immediate fixes from the user's 0.3.0 screenshot feedback:

- The workspace mode tabs (Archive View / Camera Triage / Photo Logs / Archive Triage) and
  the Open in Finder button moved from the in-content header row into the window toolbar
  (principal placement) — "should be top".
- The header's duplicate Inspector and Keyboard Shortcuts buttons removed (both already
  exist in the trailing toolbar group) — "duplicate button".
- The header pane now shows only context: mode caption + detail, breadcrumb, next-action
  hint. One less control row above the grid.

Remaining 0.3.0 feedback items are recorded in the -097 spec ("User feedback from 0.3.0
test") and land with their work packages: sidebar keyboard navigation and subfolder image
previews with a speed toggle (WP3), per-photo GPS/location assignment (WP4). Item -096 (map
render fix) was closed as user-tested.

## Files changed

- Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift (HeaderPaneView slimmed; new
  ToolbarModeControls)
- Sources/PhotoDiaryTriage/ContentView.swift (principal toolbar item)
- APP_RELEASE.env (0.3.1 / 130 / toolbar-header-cleanup)
- changelog/backlog/PDT-2026-07-03-097-photo-diary-completion-plan.md (feedback section)

## Verification performed

- `swift build` passes; bundle built; installed to /Applications/Walkfolio.app (0.3.1).
- Manual GUI check pending user test (toolbar layout is not unit-testable here).

## Known gaps / follow-ups

- If the principal toolbar item crowds narrow windows, the segmented labels may truncate;
  revisit with iconsOnly segments if the user reports it.

## Test handoff

**Please test APP_VERSION 0.3.1 (build 130), /Applications/Walkfolio.app.** Intended
user-visible behavior: the mode tabs and Open in Finder now sit in the window's top toolbar
row; the old header row below shows only the context text (no duplicated Inspector/Shortcuts
buttons); everything else unchanged from 0.3.0.
