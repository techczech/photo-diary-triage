# PDT-2026-03-24-025 Instruction Cleanup And Backlog Normalization

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.27`
- Target feature slug: `instruction-cleanup-backlog-normalization`

## User Request

Rewrite the agent instructions so the repo stays focused on speed and usability, add nested AGENTS files for app and test priorities, and normalize stale backlog state so tracking does not drift from the code.

## Constraints

- Root `AGENTS.md` must stay short and top-heavy.
- Detailed tracking workflow belongs in `changelog/AGENTS.md`, not duplicated in the root file.
- Backlog and changelog must be reconciled without rewriting JSONL history.
- Normalize stale backlog items before claiming any new usability work is active.

## Implementation Intent

- Rewrite the root `AGENTS.md` so the first rules are backlog/changelog accuracy, usability over refactors, and keyboard-first triage quality.
- Add focused nested AGENTS files in `Sources/PhotoDiaryTriage` and `Tests/PhotoDiaryTriageTests`.
- Update stale backlog specs so their status reflects what the code and changelog already show.
- Append normalization events to `backlog.jsonl` for resolved, implemented, or partially implemented items.

## Test Conditions

- Root and nested AGENTS files are present and readable.
- Backlog items `001`, `003`, `005`, `006`, `009`, and `010` no longer contradict the current code/changelog state.
- `swift build` and `swift test` still pass after the documentation/tracking changes.

## Success Criteria

- Agents can no longer follow stale backlog state without seeing an explicit normalization record.
- Root instructions are minimal and clear about the actual product priorities.
- Tracking files match the current implementation reality before new UI work proceeds.
