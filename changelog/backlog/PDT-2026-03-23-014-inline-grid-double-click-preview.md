# PDT-2026-03-23-014 Inline Grid Double-Click Preview

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.13`
- Target feature slug: `inline-grid-double-click`

## User Request

Restore double-click preview opening in the grouped inline grid without regressing the new single-click-select behavior.

## Constraints

- Single click in the grouped inline grid must continue to select only.
- Double click in the grouped inline grid must select and open the full-photo preview.
- The fix must ship through the repo tracking and release workflow.

## Implementation Intent

- Replace the fragile SwiftUI tap-combination logic with an explicit macOS click handler for inline grid items.
- Keep single-click and double-click behaviors separate and deterministic.
- Ship the fix as release `0.1.13`.

## Test Conditions

- Single click selects without opening preview.
- Double click opens preview for the selected photo.
- Collapsed preview-strip behavior remains unchanged.

## Success Criteria

- Grouped inline grid uses select-on-single-click and preview-on-double-click reliably.
