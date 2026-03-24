# PDT-2026-03-24-035 Grouped Review Performance Regression Fix

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.37`
- Target feature slug: `grouped-review-performance-regression-fix`

## User Request

The grouped-review visible-media fallback reintroduced bad lag and wiped out the earlier speed improvements. Responsiveness must return without removing grouped review.

## Constraints

- Preserve grouped review visibility from `0.1.36`.
- Restore the review responsiveness gains from the earlier speed work.
- Avoid repeated synthetic section rebuilding during SwiftUI body recomputation.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Cache inline day sections and organized inline sections in `AppState` as derived state.
- Invalidate those caches only when the selected node, visible source media, archive media cache, grouping data, or organization mode changes.
- Keep grouped review behavior the same while removing the hot recomputation path.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Grouped review remains available in normal review contexts.
- Review responsiveness no longer regresses after enabling grouped review from visible media.

## Success Criteria

- Speed improvements return while grouped review remains available.
- Review-grid interactions no longer lag because grouped section derivation is recomputed on every body update.
