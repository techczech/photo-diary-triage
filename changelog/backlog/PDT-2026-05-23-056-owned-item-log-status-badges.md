# PDT-2026-05-23-056: Owned Item Log Status Badges

## User Request Summary

Owned source items currently show `Undecided` because the SD-card scan has no local triage state. The source view should show that a file is in a log and also show the status from that owning log. When opening a copied log, copied state should remain visible rather than disappearing.

## Constraints

- Keep the source view faithful to the SD card.
- Do not lose existing `In Log` / `Copied` ownership visibility.
- Do not make owned source items look undecided when the owning log has an S/C/X status.
- Keep the status visible in grid and list rows.
- Preserve collision protection based on workspace-scoped relative paths.

## Implementation Intent

- Extend ownership snapshots to carry the owning log item selection state.
- Let review cards render an effective status from the owning log when browsing the source inbox.
- Keep copied state visible when browsing a photo log directly.
- Add regression coverage for source-view log status and copied-log badge visibility.

## Test Conditions

- Source inbox items owned by a log show that log's selection state instead of the rescanned item's `Undecided` state.
- Source inbox items owned by a copied log still show copied ownership.
- Photo-log items with imported-or-beyond lifecycle state show copied state when the log is open.
- Full review workflow tests continue to pass.

## Success Criteria

- A copied or assigned photo is never presented as merely `Undecided` when its owning log has a status.
- Opening a copied log still makes copied/imported state visible on the photo rows.

## Current Status

Approved for implementation.

## Target Release

- APP_VERSION: 0.2.17
- APP_BUILD: 94
- APP_FEATURE_SLUG: owned-item-log-status-badges
