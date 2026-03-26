# PDT-2026-03-26-020 Mutation Latency Recovery Report

- Item ID: `PDT-2026-03-26-020`
- Shipped release version: `0.1.58`
- Shipped feature slug: `mutation-latency-recovery`

## Summary Of What Changed

- Stopped routine triage mutations from triggering full browser-tree rebuilds.
- Stopped routine session mutations from flushing decoded thumbnail caches.
- Replaced synchronous main-thread session persistence after every mutation with debounced background persistence.
- Removed expensive archive-plan recomputation from the normal session-cache refresh path.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift`

## Verification Performed

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`

## Known Gaps Or Follow-Up Items

- This release is aimed specifically at the remaining interaction beat reported after `0.1.57`; it still needs real user validation on a large live session.
- The grouped-review `Escape` behavior remains a separate known follow-up and is not addressed here.

