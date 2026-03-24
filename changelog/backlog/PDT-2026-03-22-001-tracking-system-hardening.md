# PDT-2026-03-22-001 Tracking System Hardening

## Status

- Current status: `awaiting_user_review`

## User Request

Replace the loose markdown backlog/changelog process with a stronger repository-native workflow:

- use a dedicated `changelog/` folder
- keep append-only backlog and changelog indexes as JSONL
- require a spec markdown file before any work starts
- require a report markdown file after work finishes
- require nested agent instructions for the tracking folder
- keep the repository, not chat, as the authoritative record of work

## Constraints

- The workflow must live in the repo.
- Tracking indexes must be append-only JSONL, not editable markdown lists.
- The spec file must exist before implementation.
- The report file must exist before a change is presented as complete.
- Root `AGENTS.md` must force agents to confront tracking state before work.

## Implementation Intent

- Add `/changelog/AGENTS.md` as nested instructions for the tracking tree.
- Add `/changelog/backlog.jsonl` and `/changelog/changelog.jsonl`.
- Add `/changelog/backlog/` for spec markdown files.
- Add `/changelog/changelog/` for report markdown files.
- Update root `AGENTS.md` so the JSONL workflow is canonical.
- Keep lowercase `agents.md` aligned so there is no casing drift.
- Mark legacy root markdown backlog/changelog files as superseded pointers.

## Test Conditions

- `AGENTS.md` points to the JSONL workflow and nested tracking instructions.
- `changelog/AGENTS.md` defines required structure and workflow.
- `backlog.jsonl` exists and contains valid JSON lines referencing markdown files.
- `changelog.jsonl` exists and contains valid JSON lines referencing markdown files.
- A backlog spec markdown file exists for this request.
- A changelog report markdown file exists for this request.
- Legacy root tracker files no longer present themselves as canonical.

## Success Criteria

- Future work cannot reasonably proceed without first touching the tracking system.
- The repo contains a full example of the intended workflow for this request.
- The authoritative process is explicit enough that another agent can follow it without relying on chat history.
