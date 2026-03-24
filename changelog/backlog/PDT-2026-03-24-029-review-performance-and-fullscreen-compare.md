# PDT-2026-03-24-029 Review Performance And Fullscreen Compare

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.31`
- Target feature slug: `review-performance-and-fullscreen-compare`

## User Request

The core review features now mostly work, but the app is still far too slow for real triage. Speed must improve dramatically, and compare must stop behaving like a small popup and instead take over the available screen so decisions can be made at full size.

## Constraints

- Prioritize speed and review usability over cleanup or additional refactors.
- Preserve the working grid, selection, and keyboard behavior while improving performance.
- Compare should become a dedicated full-screen decision surface, not a cramped secondary popup.
- The release handoff must name the exact version to test and ask the user to test it.

## Implementation Intent

- Remove obvious render-time hotspots in the review grid, especially repeated archive-plan computation and repeated thumbnail image loads.
- Cache review-only data that is stable for the current session and invalidate it when the session changes.
- Present compare as a full-screen surface that uses the whole display for inspection.
- Verify the speed-focused slice with automated tests and a rebuilt app bundle.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- The review grid scrolls and opens materially faster than `0.1.30`.
- Compare opens as a full-screen experience instead of a small popup sheet.

## Success Criteria

- Review browsing is substantially more responsive on real sessions.
- Compare uses the full available screen and is suitable for side-by-side decisions.
- The shipped build is clearly identified for user testing.
