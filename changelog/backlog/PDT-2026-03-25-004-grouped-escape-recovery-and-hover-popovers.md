# PDT-2026-03-25-004 Grouped Escape Recovery And Hover Popovers

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.43`
- Target feature slug: `grouped-escape-recovery-and-hover-popovers`

## User Request

The new grouped enter and drill-in flow only works partly. Escape from the grouped drill-in path produces a broken blank state instead of returning cleanly to grouped-section selection, and the shortcut hover hints still do not appear in the real app.

## Constraints

- Preserve the working grouped Return and Cmd-Return behavior from `0.1.42`.
- Preserve the compact shortcut-only hint content.
- Fix the grouped Escape return path without reintroducing any grouped-review lag.
- Release handoff must name the exact version to test and explicitly ask the user to test it.

## Implementation Intent

- Harden grouped Escape recovery by restoring grouped review through the normal grouped-review state transition instead of a partial manual state mutation.
- Add regression coverage for escaping out of grouped drill-in back to the full grouped review set.
- Replace the fragile in-layout shortcut bubbles with hover popovers that are not clipped by surrounding view layout.

## Test Conditions

- `swift build` succeeds.
- `swift test` succeeds.
- Escape from grouped drill-in returns to grouped review without a blank or empty view.
- Shortcut hints appear on hover in the running app.

## Success Criteria

- Grouped Escape reliably returns from scoped section review to grouped-section selection.
- Shortcut hover hints are visible in the real UI, not just present in code.
