# PDT-2026-03-23-007 Inline Sections Entrypoint Fix

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.5`
- Target feature slug: `inline-sections-entrypoint-fix`

## User Request

Fix the `0.1.3` inline day-sections feature so it actually appears in the normal app workflow instead of being hidden after relaunch.

## Constraints

- The fix must preserve the `Years -> Months -> Days` hierarchy.
- The app should land on the first useful photo-bearing level after session recovery and normal SSD auto-load.
- The fix should not require manual sidebar drilling just to reveal the inline day-sections feature.
- Tracking must explicitly reflect that `PDT-003` shipped but did not surface correctly in the main launch path.

## Implementation Intent

- Fix session recovery so restored sessions select the preferred inline-capable node instead of `session-root`.
- Fix same-folder SSD auto-load handling so launch state does not leave the user stuck on the old entry point.
- Verify that month/day browsing actually shows the `Show By` inline-sections controls in normal use.

## Test Conditions

- Relaunching with a recovered session lands at the inline-capable node rather than `session-root`.
- Launching with the default SSD already mounted shows the inline day-sections UI when the selected path should support it.
- The `Show By` segmented control is visible in the month/day inline browser without requiring extra recovery workarounds.

## Success Criteria

- The user can see the `0.1.3` feature in the normal app flow.
- Inline day sections are no longer hidden by recovery or same-folder auto-load state.

## Tracking Notes

- The original implementation report for this item incorrectly recorded the shipped release as `0.1.6` with feature slug `deterministic-app-rebuild`.
- Tracking cleanup corrected that mismatch so this item now records release `0.1.5` with feature slug `inline-sections-entrypoint-fix`.
