# PDT-2026-03-23-013 Inline Preview And Selection Behavior

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.11`
- Target feature slug: `inline-preview-selection`

## User Request

Fix inline preview strips and grouped-grid interactions so preview strips are representative and single-click selection does not immediately open the photo preview.

## Constraints

- Collapsed preview strips must sample across the section instead of showing only the first few photos.
- In burst-aware contexts, preview strips should prefer one representative photo per burst before filling remaining slots.
- Clicking a collapsed preview thumbnail should expand the relevant section path and select/reveal that photo in the grouped grid.
- In the expanded grouped grid, single click selects and double click opens the full-photo preview.

## Implementation Intent

- Add representative preview sampling for nested inline sections.
- Update preview-strip clicks to expand/select/reveal without opening the full-photo popup.
- Update the inline grouped photo grid to use single-click selection and double-click preview opening.
- Ship the interaction fix as release `0.1.11`.

## Test Conditions

- Preview strips no longer show only the first N photos.
- Burst-aware sections show one representative per burst where possible.
- Clicking a preview-strip thumbnail expands to and selects the correct photo in the main grouped surface.
- Single click in the grouped grid selects, double click opens preview.

## Success Criteria

- Inline grouped browsing feels selection-first and preview strips are representative of the section content.

## Review Follow-Up

- User testing on release `0.1.11` confirmed preview-strip clicks are fixed.
- User testing also found that grouped-grid single clicks still open preview, so the interaction path needs a follow-up fix before approval.
