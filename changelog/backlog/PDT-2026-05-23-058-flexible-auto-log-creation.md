# PDT-2026-05-23-058: Flexible Automatic Log Creation

## User Request Summary

Copying selected source photos should not fail with a raw lifecycle error when the user forgot to create or reopen a photo log. The app should support a more flexible workflow: select or exclude photos, copy, and have an automatic date-named log created; then select more photos and choose whether to add them to the existing log or start a new one. The user should also be able to start a log first and have later selections added to that log.

## Constraints

- Do not expose internal lifecycle transition names in user-facing copy failures.
- Preserve the SSD-first selective-import workflow.
- Keep destructive source cleanup separate from copy/log creation.
- Keep imported or source-cleaned logs locked for direct membership edits.
- Prefer automatic recovery over blocking when included source photos can be safely copied.
- Keep the current explicit create/edit log flows working.

## Implementation Intent

- Diagnose why copied source items can enter copy directly from `source_cleanup_pending` and fail transition validation.
- Add a copy path that creates an automatic date-named photo log when included source items are ready but no editable log is active.
- Keep the new automatic log open enough that later selections can be deliberately added to it or split into a new log.
- Replace raw lifecycle failure text with a plain-language status that tells the user what happened and what to do next.
- Add regression coverage for copy without prior explicit photo-log creation.

## Test Conditions

- Copying included source inbox items without an active photo log creates a dated photo log and copies those items.
- The copy failure shown in the screenshot is not reproduced for a valid source selection.
- Existing explicit photo-log creation and copy still pass.
- Imported and source-cleaned logs remain locked for direct membership edits.
- Full tests continue to pass.

## Success Criteria

- The user can select photos and click Copy without first creating a log.
- The app creates or continues a sensible photo-log context instead of failing with lifecycle internals.
- After copying one group, the next source selection offers a clear continuation choice: add to the current log or start a new log.
- The workflow remains non-destructive unless cleanup is explicitly confirmed.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.19
- APP_BUILD: 96
- APP_FEATURE_SLUG: flexible-auto-log-creation
