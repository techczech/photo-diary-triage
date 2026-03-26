# PDT-2026-03-26-028 Candidate Triage State And RAW Promotion

- Item ID: `PDT-2026-03-26-028`
- Title: `Candidate triage state and RAW promotion`
- Current status: `approved_for_implementation`
- Target release version: `0.1.66`
- Target feature slug: `candidate-triage-state-and-raw-promotion`

## User Request Summary

The user wants a new `Candidate` triage state for photos that are possible imports but not confirmed yet, and a matching candidate filter. The user also wants `R` to behave as a stronger action: turning RAW on should also promote the photo into the import-selected state.

## Constraints

- Keep the keyboard-first triage workflow intact.
- Preserve the current explicit include, exclude, and undecided states.
- Do not break compare, preview, or grouped review flows.
- Keep RAW toggling fast and consistent across review grid, list, and compare.

## Implementation Intent

- Add a new `candidate` selection state to the core model.
- Add a `Candidate` filter to the review toolbar and filter logic.
- Add `C` as the single-key candidate shortcut and candidate actions to the review surfaces.
- Update `R` so enabling RAW also marks the item as included for import.
- Keep compare available from the command-path shortcut rather than the single-key `C`.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - `C` marks the focused item as candidate
  - candidate items are visible under a candidate filter
  - `R` enables RAW and promotes the item to included
  - compare still works from its command shortcut and button path

## Success Criteria

- Candidate is a real persisted triage state with visible status styling.
- Candidate has its own review filter.
- RAW enablement promotes the item to included instead of staying detached from import intent.
- Grid, list, compare, and keyboard paths stay coherent.
