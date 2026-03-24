# PDT-2026-03-23-003 Inline Collapsible Folder Sections

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.3`
- Target feature slug: `inline-folder-sections`

## User Request

Add a day-first inline browser so photos can be seen at higher folder levels without drilling through separate synthetic folder nodes.

## Constraints

- Top-level hierarchy remains `Years -> Months -> Days`.
- Days are the primary structure.
- Bursts and time clusters are nested within days, not competing top-level organizations.
- If a folder resolves to exactly one day, it auto-expands immediately.
- If multiple days exist, they start collapsed with counts and tiny preview strips plus an `Expand All` control.
- Must preserve the existing terminal review grid for full review actions.

## Implementation Intent

- Add an inline day browser for month/day-level browsing.
- Add review modes:
  - `Days`
  - `Days + Bursts`
  - `Days + Clusters`
  - `Days + Clusters + Bursts`
- Keep previews small and lazy for speed.
- Keep the existing full review grid reachable from the inline browser.

## Test Conditions

- Month/day views can show inline day sections.
- Single-day views auto-expand.
- Multi-day views start collapsed and support `Expand All`.
- The chosen review mode changes which nested sections are visible inside each day.
- Tiny preview strips load quickly without trying to render the whole review surface at once.

## Success Criteria

- The user can stay on a higher-level folder page and inspect days inline.
- Bursts and clusters appear as nested optional structure inside days.
- The app feels lighter because inline browsing uses tiny previews first.
