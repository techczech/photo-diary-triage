# PDT-2026-03-26-019 Performance Regression Recovery

- Item ID: `PDT-2026-03-26-019`
- Title: `Performance regression recovery`
- Current status: `approved_for_implementation`
- Target release version: `0.1.57`
- Target feature slug: `performance-regression-recovery`

## User Request Summary

The current design is in a good place, but responsiveness has regressed again. The app needs a broad performance pass to get back to the earlier "instant" feel. The user explicitly asked for no animations and wants all interactions to feel immediate.

## Constraints

- Do not add animations anywhere.
- Preserve the current review and compare design unless a change directly improves responsiveness.
- Keep keyboard-driven triage intact.
- Prioritize real interaction speed over refactors or internal cleanup.

## Implementation Intent

- Identify and remove synchronous image decoding from SwiftUI render paths.
- Deduplicate and cache image decode work so repeated view updates do not hit disk again.
- Remove the remaining animated scroll/focus transitions in review and grouped review.
- Preserve existing compare, preview, and review behavior while restoring responsiveness.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual user verification on large review sets:
  - opening a review set
  - scrolling the main grid
  - switching grouped/flat review
  - opening compare and preview

## Success Criteria

- Opening and scrolling review feels immediate again.
- No visible animated lag remains in review navigation or scroll jumps.
- Thumbnail and full-image loading no longer blocks the main UI thread during normal browsing.
- Existing review, compare, and preview behavior still works.

