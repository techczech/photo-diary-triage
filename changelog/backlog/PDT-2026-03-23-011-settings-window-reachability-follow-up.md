# PDT-2026-03-23-011 Settings Window Reachability Follow-Up

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.9`
- Target feature slug: `settings-window-fit`

## User Request

Follow up on the failed `0.1.8` settings-window fix so all Settings controls are actually reachable in the running app.

## Constraints

- The Settings window must stay usable from both the menu item and the sidebar button.
- The fix must make grouping and backup controls reachable without relying on hidden behaviour.
- The release and tracking workflow must be updated for the follow-up fix.

## Implementation Intent

- Make the Settings surface large enough for the current controls and keep vertical scrolling enabled as fallback.
- Ensure the scroll view expands to the full window width and the lower controls remain reachable.
- Rebuild and relaunch the packaged app as release `0.1.9`.

## Test Conditions

- Settings still opens normally.
- Grouping and backup controls are reachable in the default window.
- If the window becomes smaller, vertical scrolling still works.

## Success Criteria

- The user can reach the grouping controls and lower settings content in the packaged app.
