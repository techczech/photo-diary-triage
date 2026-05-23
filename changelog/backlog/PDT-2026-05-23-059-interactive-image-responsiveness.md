# PDT-2026-05-23-059: Interactive Image Responsiveness

## User Request Summary

The app should feel nearly instant on this Mac. Clicking, keyboard shortcuts, archive photo loading, compare entry, and zooming should respond much faster.

## Constraints

- Preserve the SSD-first selective-import workflow.
- Keep keyboard-driven triage responsive.
- Keep preview and compare as fast decision surfaces.
- Prioritize visible images and nearby content before off-screen work.
- Avoid broad redesign or unrelated refactors.
- Keep archive, compare, and zoom behavior correct while reducing perceived latency.

## Implementation Intent

- Inspect archive and compare image-loading paths for repeated disk reads, main-thread decode work, and unnecessary view rebuilding.
- Add bounded image caching or preloading where it directly improves visible interactions.
- Make compare and zoom transitions reuse already-loaded image data when possible.
- Keep cancellation and memory use bounded so large sessions stay usable.
- Add focused regression coverage where the performance change touches shared state or interaction behavior.

## Test Conditions

- Archive view opens and loads visible photos faster after the first scan.
- Switching to compare from a selected item does not wait on avoidable reload work.
- Zooming and panning do not trigger avoidable disk reloads.
- Keyboard shortcuts still affect the active review surface correctly.
- Full tests continue to pass.

## Success Criteria

- Visible archive thumbnails and selected image previews appear from cache after first load.
- Compare view can reuse warm images from the archive/review path.
- Zoom and pan remain visually stable and responsive.
- The implementation stays scoped to image-loading responsiveness.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.20
- APP_BUILD: 97
- APP_FEATURE_SLUG: interactive-image-responsiveness
