# PDT-2026-03-24-011 Concurrent Thumbnail Generation

## Status

- Current status: `draft`
- Priority: P2
- Target release version: TBD
- Target feature slug: `concurrent-thumbnails`

## User Request

Generate thumbnails in parallel with viewport-aware prioritization to reduce visible lag.

## Constraints

- Must not overwhelm system resources (limit concurrency).
- Visible items should be prioritized over off-screen items.
- Cache invalidation behavior must be preserved.

## Implementation Intent

- Use `TaskGroup` in `PreviewStore` for concurrent thumbnail generation.
- Limit to 4-6 concurrent generations.
- Accept a priority list (visible item IDs) to process first.
- Maintain existing cache key strategy (MD5 hash).

## Test Conditions

- Thumbnail generation for 100+ items completes faster than sequential.
- Visible items appear before off-screen items.
- No duplicate generation for cached items.

## Success Criteria

- Noticeable reduction in time-to-thumbnails for large sessions.
