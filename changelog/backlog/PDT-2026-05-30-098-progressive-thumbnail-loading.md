# PDT-2026-05-30-098 progressive thumbnail loading

item_id: PDT-2026-05-30-098
title: Progressive thumbnail loading and speed indicator
status: approved_for_implementation
target_release_version: 0.2.53
target_feature_slug: progressive-thumbnail-loading

## User Request Summary

Thumbnail loading is too slow. The grid waits too long, then thumbnails appear in a burst or fall back to retry. Improve time-to-first-thumbnail, make thumbnails appear progressively, add a speed/progress indicator, and research the right approach before changing the implementation.

## Constraints

- Preserve keyboard-first triage, mouse selection, preview, compare, and SSD-first selective import.
- Prioritize visible and nearby thumbnails before off-screen work.
- Avoid unbounded background work.
- Do not replace the current review workflow or cache identity model without evidence.
- Keep backlog, changelog, and `APP_RELEASE.env` aligned.

## Detailed Analysis Plan

### A. Current Pipeline Trace

- Find thumbnail request entry points in grid, list, inspector, inline previews, and compare.
- Trace request path through `AppState`, scheduler, preview store, persistent cache, memory cache, and retry state.
- Identify where progress can be counted without adding duplicate work.
- Evidence required: source files, data flow, current tests, and previous speed reports.

### B. Progressive Loading Analysis

- Verify whether individual cells publish as each thumbnail completes or wait on a shared batch/state refresh.
- Check actor/main-thread hops for delayed UI delivery.
- Check whether scheduler ordering lets visible requests sit behind old/off-screen work.
- Success target: first completed thumbnail updates its own cell immediately; later thumbnails continue filling independently.

### C. Speed Indicator Analysis

- Identify user-visible state needed: loaded count, failed count, in-flight count, queued count, elapsed time, and recent thumbnails-per-second.
- Decide where to show the indicator without crowding review controls.
- Confirm reset rules when source/session changes or retry is triggered.
- Success target: user can see active thumbnail progress and rough loading speed while the grid fills.

### D. Faster Loading Analysis

- Research Apple-supported thumbnail/decode APIs and options relevant to macOS app thumbnail grids.
- Compare current persistent PNG cache, memory cache, QuickLook/ImageIO generation, and requested pixel sizes.
- Look for duplicate disk reads, excessive file existence checks, serial bottlenecks, and cache misses caused by size or key mismatch.
- Success target: reduce visible lag using bounded concurrency, viewport-aware priority, cache-first delivery, and smaller correctly-sized decode work.

### E. Verification Plan

- Add focused tests for scheduler/progress behavior where practical.
- Keep existing review interaction tests green.
- Build the app bundle and name exact version for user testing.
- Manual check: large grid opens with progressive thumbnail fill, visible progress/speed text, and usable retry state.

## Implementation Intent

- Add a thumbnail loading progress model owned by app state or the scheduler.
- Make visible thumbnail completion publish progressively without waiting for unrelated thumbnails.
- Strengthen scheduler priority so current viewport/nearby cells outrank stale or off-screen requests.
- Improve cache-first and decode-size paths if analysis confirms they are the bottleneck.
- Surface progress/speed in the review UI.

## Test Conditions

- `swift build`
- Focused thumbnail scheduler/progress tests.
- Relevant existing tests if the local toolchain supports them.
- `./scripts/build_app_bundle.sh` if available and still current.

## Success Criteria

- Visible grid thumbnails appear progressively rather than all at once.
- The UI shows active thumbnail loading progress and recent speed.
- Retry remains available for failures but is no longer the common visible state for slow loads.
- Loading uses bounded, visible-first work and is measurably faster or removes the observed batching bottleneck.
- Handoff names `APP_VERSION 0.2.53` and asks the user to test that version.
