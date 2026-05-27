# PDT-2026-05-27-077 crop feedback and immediate preview

item_id: PDT-2026-05-27-077
title: Crop feedback and immediate preview
status: awaiting_user_review
target_release_version: 0.2.34
target_feature_slug: crop-feedback-immediate-preview

## User Request

Fix crop feedback and state change.

User reports:

- crop button appears to do nothing
- no clear state change after crop creation
- repeated clicking creates multiple crops accidentally
- app must always make clear that a crop was created
- photo should change to the cropped version after crop save

## Constraints

- Preserve non-destructive original file behavior.
- Do not remove existing crop manifest behavior.
- Keep preview and compare crop actions keyboard reachable.
- Avoid broad preview/compare redesign.
- Update `APP_RELEASE.env`.
- Create changelog report and JSONL updates after implementation.

## Implementation Intent

- Track crop save in progress and disable crop controls while saving.
- Add clear saving/saved feedback in preview and compare crop controls.
- After crop save, create/load a `MediaItem` for the crop output.
- Add the crop item to the active session or archive cache.
- Link original and crop relationships in memory immediately.
- Switch preview/focus/selection to the newly created crop.
- Refresh review, compare, inspector, and navigation state.

## Test Conditions

- Focused crop tests cover immediate crop insertion.
- Existing crop scanner/filter tests still pass.
- Build app bundle for `APP_VERSION=0.2.34`.

## Success Criteria

- One crop click cannot silently create multiple outputs through accidental repeated clicks.
- User sees visible crop-in-progress feedback.
- User sees visible crop-created feedback with output filename.
- Preview changes to the cropped image immediately after the crop is written.
- `Cropped` filter contains the new crop without requiring manual reload.
- Badge link between original and crop works immediately.

## Implementation Notes

- Shipped in `APP_VERSION=0.2.34`.
- Crop controls disable while the item is saving.
- The saved crop is inserted into the active app model and focused immediately.
- XCTest verification is blocked on this machine by missing XCTest platform paths in Command Line Tools.
