# PDT-2026-05-30-099 global media loading speed

item_id: PDT-2026-05-30-099
title: Global media loading speed
status: approved_for_implementation
target_release_version: 0.2.54
target_feature_slug: global-media-loading-speed

## User Request Summary

Camera triage thumbnail loading is much faster after `0.2.53`, but Archive View still takes forever. Do not solve this as a local archive-only hack. Use the archive slowdown as evidence for a broader global speed pass across media loading, thumbnails, preview, compare, and cache reuse.

## Constraints

- Preserve the `0.2.53` camera-triage thumbnail improvements.
- Keep archive browsing read-only unless the current workflow already allows otherwise.
- Prioritize visible media before off-screen media everywhere.
- Do not force broad archive downloads or expensive full-image reads while browsing.
- Prefer shared media-loading abstractions and policies over mode-specific patches.
- Keep backlog, changelog, and `APP_RELEASE.env` aligned.

## Analysis Plan

### A. Shared Media Load Map

- Trace source/camera, archive, photo log, preview, compare, and crop media-loading paths.
- Identify which code is shared and which is duplicated by mode.
- Separate scan/index time from thumbnail generation and full-image decode time.

### B. Cache Identity And Reuse

- Trace thumbnail cache keys for source items, copied archive items, crop outputs, and archive-scanned items.
- Check whether the same photo gets a different cache identity after import/copy.
- Reuse existing thumbnails globally when metadata proves the cached thumbnail is for the same file content.

### C. Scheduling And Progressive Delivery

- Confirm first visible cells outrank off-screen prefetch in every review surface.
- Confirm progress/speed telemetry covers source and archive paths consistently.
- Avoid repeated task resets or retries that make slow work look failed.

### D. Archive Cloud/OneDrive Risk

- Inspect existing archive/OneDrive research notes and code safeguards.
- Avoid changes that read all archive file bytes merely to make browsing look rich.
- Keep mode-specific behavior only for real domain constraints such as online-only archive files.

### E. Implementation Pass

- Build shared fixes first: cache-key reuse, progressive delivery, scheduling, and decode/preheat policy.
- Add mode-specific archive behavior only when required by cloud/offline safety.
- Add focused tests for shared behavior plus the archive regression that revealed it.

## Implementation Intent

- Make source, archive, photo-log, preview, and compare media loading use the same fast path where possible.
- Reuse existing thumbnail cache entries when the same photo moves from source to archive.
- Keep first visible media and nearby items ahead of bulk prefetch globally.
- Keep retry for real failures.

## Test Conditions

- `swift build`
- Focused tests for shared thumbnail/cache/scheduling behavior.
- Full `swift test` if local toolchain remains healthy.
- Build app bundle for `APP_VERSION 0.2.54`.

## Success Criteria

- Archive View no longer waits on avoidable thumbnail regeneration for already-known photos.
- Source and archive thumbnails appear progressively with the existing speed indicator.
- Shared media-loading improvements avoid special-case hacks where one common fix works.
- Camera triage thumbnail behavior remains fast.
- Handoff names `APP_VERSION 0.2.54` and asks the user to test that version.
