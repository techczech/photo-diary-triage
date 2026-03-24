# PDT-2026-03-23-010 Settings Window Scrollability

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.8`
- Target feature slug: `settings-scrollability`

## User Request

Fix the Settings window so the newly added controls remain reachable instead of being clipped by the fixed window height.

## Constraints

- The fix must preserve the existing Settings contents and keep the window usable from the app menu and sidebar button.
- The Settings surface must remain usable on normal displays without requiring hidden gestures.
- The change must ship through the same release/tracking workflow as other app fixes.

## Implementation Intent

- Make the Settings content scroll vertically when it exceeds the available window height.
- Preserve the existing layout and controls while ensuring lower sections like grouping and backup stay reachable.
- Rebuild and relaunch the packaged app as release `0.1.8`.

## Test Conditions

- Opening Settings from the menu or button still works.
- The Settings window allows scrolling when content exceeds the visible area.
- The grouping and backup controls are reachable without resizing the app window.

## Success Criteria

- The Settings window is fully usable and all controls can be reached.
