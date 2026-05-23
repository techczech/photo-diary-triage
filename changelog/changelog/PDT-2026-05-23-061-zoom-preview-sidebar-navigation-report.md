# PDT-2026-05-23-061: Zoom, Preview, And Sidebar Navigation Report

## Summary

- Fixed single-photo preview zoom inspection by moving it onto the controllable AppKit scroll canvas.
- Added keyboard pan routing for zoomed single-photo preview via H/J/K/L.
- Made the single-photo preview open as a much larger screen-filling inspection sheet.
- Let zoomed compare images receive pan/scroll input by disabling the click-selection overlay while zoomed in.
- Replaced the sidebar outline with explicit disclosure state and auto-expansion through year nodes so month folders are visible by default.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift`
- `changelog/backlog/PDT-2026-05-23-061-zoom-preview-sidebar-navigation.md`

## Verification Performed

- `swift test`
  - 112 tests passed.
- `./scripts/build_app_bundle.sh`
  - Built `dist/PhotoDiaryTriage.app`.
- `open -n dist/PhotoDiaryTriage.app && sleep 2 && pgrep -fl PhotoDiaryTriage`
  - Confirmed the packaged app launched from `dist/PhotoDiaryTriage.app`.

## Known Gaps Or Follow-Up Items

- Live visual confirmation of the exact feel of trackpad/mouse panning still needs user testing on real photos.
- The compare image click-selection overlay is disabled while zoomed in so pan/scroll input can reach the image surface; selecting the compare item from the image area works again after returning to fit zoom.

## Shipped Release

- shipped version: `0.2.22`
- shipped build: `99`
- shipped feature slug: `zoom-preview-sidebar-navigation`
