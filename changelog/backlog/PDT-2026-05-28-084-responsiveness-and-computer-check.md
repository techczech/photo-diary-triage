# PDT-2026-05-28-084 responsiveness and Computer check

item_id: PDT-2026-05-28-084
title: Responsiveness and Computer check
status: approved_for_implementation
target_release_version: 0.2.40
target_feature_slug: responsiveness-computer-check

## User Request

After implementing all crop repair chunks, run a speed optimization pass across the app, build it, and use Computer Use to check the running app.

## Constraints

- Performance pass must cover the app broadly, not only crop.
- Keep grid browsing responsive and legible.
- Preserve keyboard-driven triage and mouse selection behavior.
- Use Build macOS Apps build/run practices.
- Use Computer Use for final UI inspection after build/install/launch.

## Implementation Intent

- Review expensive UI invalidation, cache churn, thumbnail/display-image work, and interaction paths.
- Apply targeted optimizations that reduce unnecessary refreshes or repeated work.
- Build the SwiftPM macOS app bundle.
- Install and launch the built app.
- Use Computer Use to inspect the running app window and verify basic responsiveness/visibility.

## Test Conditions

- `swift build`.
- focused SwiftPM tests where the local toolchain permits.
- app bundle build with release metadata.
- installed bundle metadata check.
- Computer Use app-state inspection of the launched app.

## Success Criteria

- App builds and launches from `/Applications/PhotoDiaryTriage.app`.
- Final installed version metadata matches the completed release.
- Review UI is visible and interactive in Computer Use inspection.
- No obvious blank window, launch failure, or unusable layout.
