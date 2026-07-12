# PDT-2026-07-12-098 Codebase review and next-step recommendation

item_id: PDT-2026-07-12-098
title: Codebase review and next-step recommendation
status: review_complete_pending_user_direction
target_release_version: TBD after review
target_feature_slug: TBD after review

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
