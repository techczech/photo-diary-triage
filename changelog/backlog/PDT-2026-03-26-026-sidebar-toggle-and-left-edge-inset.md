# PDT-2026-03-26-026 Sidebar Toggle And Left Edge Inset

- Item ID: `PDT-2026-03-26-026`
- Title: `Sidebar toggle and left edge inset`
- Current status: `implemented_pending_review`
- Target release version: `0.1.64`
- Target feature slug: `sidebar-toggle-and-left-edge-inset`

## User Request Summary

The user reports that the sidebar toggle icon disappeared after the shell changes, so there is no obvious way to reopen the sidebar from the main review surface. The review content also sits too close to the left window edge when the sidebar is hidden, so the visible grid needs a small left inset again.

## Constraints

- Restore a clear, keyboard-friendly sidebar affordance.
- Keep the app-managed sidebar shell behavior and current speed improvements.
- Do not bring back the heavy system sidebar controller path.
- Keep the review grid responsive and non-overlapping.

## Implementation Intent

- Add a visible sidebar toggle button back into the top-level review chrome.
- Keep the toggle app-managed so it works with the current shell split and keyboard shortcut.
- Add a modest left inset to the review surface when the sidebar is hidden so the grid no longer starts flush against the window edge.
- Make sure the restored control does not reintroduce the old sidebar latency.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - the sidebar toggle icon is visible again
  - the sidebar can be reopened from the main review surface
  - the review grid no longer starts under the left edge
  - sidebar open/close still feels fast

## Success Criteria

- The sidebar toggle is visible in the main chrome.
- The review content has a small but clear left margin when the sidebar is hidden.
- The sidebar still opens and closes quickly.
- No regressions in review, compare, or keyboard navigation.
