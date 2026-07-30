# PDT-2026-07-12-098 Codebase review and next-step recommendation

item_id: PDT-2026-07-12-098
title: Codebase review and next-step recommendation
status: design_in_review
target_release_version: 0.7.0
target_feature_slug: timeline-and-search

## User request summary

Review the current Walkfolio codebase and identify how to move the product forward.

## Constraints

- Ground the review in the approved Walkfolio 1.0 completion plan, `CONTEXT.md`,
  `DESIGN.md`, current tracking records, and the actual checkout.
- Preserve the committed full scope: no MVP framing, silent deferrals, or scope cuts.
- Do not implement interaction, layout, navigation, shortcut, modal, or workflow changes
  until the user has reviewed and approved the design direction.
- Keep this planning review separate from the versioned release implementation and handoff
  sequence.

## Implementation intent

Inspect architecture, current implementation coverage, tests, tracking consistency, and
known technical risks. Recommend the next coherent release slice and show the evidence and
design decisions that must precede implementation.

## Test conditions

- Run the current full Swift test suite without changing code.
- Inspect current build metadata and source/test structure.
- Trace the current Release D prerequisites and identify mismatches with the approved plan.

## Success criteria

- A concise, evidence-backed codebase assessment.
- A prioritised recommendation tied to the existing completion plan.
- Explicit design questions or technical blockers surfaced before implementation.
- No product code or release metadata changed during the review.

## Current status

Review complete pending user direction. No implementation authorised by this item.

## Review findings

- The repository has implemented the approved completion plan through Release C
  (`APP_VERSION=0.6.0`, `archive-index`); Releases D–I remain.
- Release D has a safety prerequisite before product UI work: Archive thumbnail backfill
  currently reads every photo directly and has no bounded hydration, post-processing
  eviction, cancellation, or free-space floor. It is unsafe to run over the real dataless
  Archive as currently implemented.
- Archive browsing still walks the physical year/month/walk folder tree and loads terminal
  Walk folders with `FileScanner`; there is no Archive Index reader, Timeline model, SQLite
  Archive cache, or FTS implementation yet.
- The full Swift package builds. The test run produced no observed assertion failures but
  did not terminate after more than a minute, so it was interrupted; full-suite green
  status is not currently verified. Swift 6 sendability warnings remain in UI bindings and
  archive migration callbacks.
- The highest-value next move is a design-reviewed Release D foundation: first harden
  Archive byte lifecycle and batch safety, then implement Index reader/cache/query models,
  then present and approve the Timeline/Search interaction design before replacing the
  current folder browser.

## Archive browsing design direction

The Archive should provide two views over the same indexed Trips:

- **Timeline** is the default view. It uses wide chronological rows with a cover image,
  title, date range, location, Walk count, and photo count. It supports linear Up and Down
  keyboard navigation and makes similar Trips easy to distinguish.
- **Contact Sheet** is the compact visual view. It uses year-banded photographic tiles and
  two-dimensional arrow-key navigation for rapid recognition.

Both views preserve the same selected Trip, year position, search query, and navigation
state. The app remembers the last chosen view. A compact view control sits beside the
`Trips` heading, while global Archive search remains in the trailing side of the toolbar.

The earlier large-card grid is rejected because it consumes more space than the Contact
Sheet while exposing less metadata than the Timeline. It does not support a distinct user
task.

This direction remains under design review. It is not a locked mockup and does not
authorise implementation.
