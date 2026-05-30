# PDT-2026-05-30-100 measured global media speed

---
item_id: PDT-2026-05-30-100
title: Measured global media speed
status: approved_for_implementation
target_version: 0.2.55
target_build: 132
target_feature_slug: measured-global-media-speed
---

## User Request Summary

The previous global media speed pass produced absolutely zero perceived speed improvement in Archive View. Work on speed until it is actually solved. Do not claim improvement from guesses or code inspection alone. Measure the initial speed before changes and the new speed after changes, with proof.

## Constraints

- Treat `0.2.54 / 131 / global-media-loading-speed` as unproven.
- Make global speed improvements, not local archive-only hacks.
- Measure the same workload before and after the implementation.
- Separate scan/index time, first visible thumbnail time, first batch time, and complete thumbnail time where possible.
- Preserve Camera Triage speed and progressive thumbnail behaviour.
- Use Computer/GUI observation when needed, but prefer deterministic instrumentation for repeatable timings.
- Keep the app responsive while work continues in the background.
- Detect OneDrive/macOS File Provider files that are online-only, dataless, or otherwise not fully local.
- Make non-local file state visible in the app instead of treating it as a generic thumbnail retry.
- Avoid accidental mass hydration of OneDrive archive photos during archive browsing.

## Implementation Intent

1. Add a repeatable benchmark or instrumentation path that exercises the same media loading and thumbnail pipeline used by Archive View and source triage.
2. Capture a baseline timing on the current implementation before optimization.
3. Profile the measured bottleneck and identify whether the delay comes from archive scanning, manifest parsing, thumbnail generation, cache lookup, thumbnail decode, or main-actor batching.
4. Research and validate OneDrive Files On-Demand behaviour on this Mac, including local/dataless detection.
5. Implement shared/global fixes in loading, thumbnail, cache, decode, scheduling, and file-locality display code.
6. Rerun the same benchmark after the fix and record before/after results in the changelog report.
7. Install and open the verified build for manual testing.

## Test Conditions

- Deterministic archive fixture with enough JPEG files to expose delayed thumbnails.
- Baseline benchmark recorded before changing the measured code path.
- Post-change benchmark recorded after optimization on the same fixture and machine.
- Focused tests for the changed shared speed path.
- Focused tests for online-only/local-file state detection and UI snapshot propagation.
- `swift test` or a justified narrower Swift test set if full tests fail for unrelated reasons.
- App bundle build, installation to `/Applications`, and launch verification.

## Success Criteria

- Archive View initial media availability is measurably faster on the benchmark.
- First visible thumbnails appear progressively and substantially earlier than baseline.
- Complete thumbnail generation time does not regress.
- Camera/source triage thumbnail loading still uses the shared fast path.
- Changelog report includes concrete baseline and post-change timing numbers.
- Archive cards and status surfaces clearly distinguish local thumbnails from cloud-only files that need download/pinning before full preview.
- OneDrive online-only archive files do not trigger silent thumbnail stalls or misleading retry states.

## Current Status

Approved for implementation. Baseline measurement pending.
