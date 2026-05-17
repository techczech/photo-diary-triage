# PDT-2026-05-04-041 Compact Review Control Bar

- Item ID: `PDT-2026-05-04-041`
- Title: `compact review control bar`
- User request summary: `Reduce the large vertical gap above grouped review photos and make display/grouping controls much more minimal, preserving the priority of maximum vertical space for photo review.`
- Constraints:
  - Preserve grid-first review and grouped review controls.
  - Keep frequent actions visible and keyboard-accessible.
  - Avoid titlebar clipping regressions from wide segmented controls.
  - Spend vertical space on photos, not review chrome.
- Implementation intent:
  - Replace the two-row material review control panel with one compact top strip.
  - Use menu-style compact controls for display, grouping, filter, and view mode.
  - Keep column controls and grouped expand/collapse actions visible in the same strip.
  - Increment the app release metadata for the fix.
- Test conditions:
  - The grouped review screen no longer has a large blank/control gap above the first group.
  - Display/grouping/filter/view controls remain reachable.
  - Review keyboard focus and existing test coverage remain intact.
- Success criteria:
  - Build `0.2.3` visibly prioritizes vertical photo space.
  - The grouped review controls are compact and do not clip at normal window widths.
- Current status: `approved_done`
- Target release version: `0.2.3`
- Target feature slug: `compact-review-control-bar`

## User Review

- 2026-05-17: User confirmed the UI improvements work in the running app.
