# PDT-2026-03-23-005 Right-Hand Details Inspector

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.14`
- Target feature slug: `details-inspector`

## User Request

Add a collapsible right-hand sidebar with detailed data for the current folder and the currently selected photo.

## Constraints

- Must remain collapsible.
- Must work for both folder-level and photo-level detail.
- Must not break the existing main review grid or keyboard flow.

## Implementation Intent

- Add a right-hand inspector panel in the main detail surface rather than a modal.
- Show folder/session summary details for the currently inspected browser node.
- Show detailed photo metadata for the focused or selected photo.
- Allow the inspector to collapse and reopen from visible UI without breaking the existing review grid.

## Test Conditions

- Inspector can be shown/hidden from visible UI.
- Folder browsing shows folder-level details in the inspector.
- Selecting a photo shows photo-level details in the inspector.

## Success Criteria

- The user can inspect detailed folder and photo data without leaving the review surface.

## Review Follow-Up

- User review on release `0.1.14` reported that the inspector was not visibly reachable in the packaged app.
- Follow-up fix needs to make the inspector column visibly present in the default window layout.
- User review on release `0.1.15` reported that the inspector can be closed but not reopened easily enough.
- Follow-up fix needs a persistent toggle affordance that remains visible when the inspector is collapsed.
