# PDT-2026-05-23-064: Photo log mode clarity

## User Request Summary

- Investigate discrepancy between on-disk copied badges and saved decisions.
- Rework unclear boundary between starting a photo log and being in photo-log mode.
- Use cognitive walkthrough to make the flow clear: what is happening, when it happens, and how to proceed next.

## Constraints

- Preserve SSD-first selective import workflow.
- Preserve keyboard-driven triage and existing source/archive modes.
- Keep copy state, decision persistence, and photo-log membership aligned.
- Use Computer Use for live app inspection.
- Use macOS SwiftUI design patterns for clearer desktop affordances.
- Do not add destructive cleanup behavior.

## Implementation Intent

- Trace copied/on-disk badge logic against saved decision and photo-log membership persistence.
- Define clearer UI state for source triage, photo-log review, and append/copy operations.
- Add user-visible guidance that names the current mode, pending action, and next step.
- Add regression tests for the decision/copy-state mismatch where practical.
- Write a cognitive walkthrough report for the revised task flow.

## Test Conditions

- `swift test`
- `./scripts/build_app_bundle.sh`
- Launch `dist/PhotoDiaryTriage.app`
- Inspect the running app with Computer Use.

## Success Criteria

- Copied/on-disk status and saved source decisions no longer imply conflicting next actions.
- The user can tell whether they are choosing photos, viewing logs, adding marked photos, or copying to disk.
- Starting a new photo log and continuing an existing log have distinct, visible affordances.
- The cognitive walkthrough names any remaining learnability gaps.
- Handoff names the exact release version for user testing.

## Current Status

- status: approved_for_implementation
- target release version: `0.2.25`
- target feature slug: `photo-log-mode-clarity`
