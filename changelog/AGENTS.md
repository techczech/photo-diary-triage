# Tracking Agents

This file governs everything under `/changelog/`.

Use this folder as the authoritative tracking system for requested work, active specs, and completed implementation reports.

## Purpose

- Keep work out of chat-only history.
- Make every request start as a spec file.
- Make every completed change end with a written report.
- Keep the backlog and changelog append-only through JSONL indexes.

## Required Structure

- [backlog.jsonl](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/backlog.jsonl)
  Append-only event log for backlog/spec lifecycle.
- [changelog.jsonl](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog.jsonl)
  Append-only event log for implementation/report lifecycle.
- [backlog/](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/backlog/)
  Markdown spec files for active or proposed work.
- [changelog/](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/)
  Markdown implementation reports for completed work.

## Required Workflow

Before doing any implementation work:

1. Create a new markdown spec in `changelog/backlog/`.
2. The spec must include:
   - item ID
   - title
   - user request summary
   - constraints
   - implementation intent
   - test conditions
   - success criteria
   - current status
   - target release version and target feature slug
3. Append a new JSON object line to `backlog.jsonl` that points to the spec file.
4. Show the spec to the user and refine it in conversation until ready.

After implementation:

1. Create a markdown report in `changelog/changelog/`.
2. The report must include:
   - item ID
   - summary of what changed
   - files changed
   - verification performed
   - known gaps or follow-up items
   - shipped release version and shipped feature slug
3. Append a new JSON object line to `changelog.jsonl` that points to the report file.
4. Append a new JSON object line to `backlog.jsonl` reflecting the latest backlog status for that item.

## JSONL Rules

- Never rewrite history in the JSONL files; always append.
- Each line must be valid JSON.
- Each line must reference a markdown file through a `file` field.
- Recommended fields:
  - `ts`
  - `item_id`
  - `event`
  - `status`
  - `title`
  - `file`
- If a file moves or a status changes, append a new line instead of editing an old one.

## Naming Rules

- Item IDs should be stable and sortable.
- Preferred format:
  - `PDT-YYYY-MM-DD-###`
- Backlog specs should use:
  - `<item-id>-<slug>.md`
- Changelog reports should use:
  - `<item-id>-<slug>-report.md`

## Guardrails

- Never implement a user request without first creating the backlog spec file.
- Never implement a user request without incrementing `APP_RELEASE.env` for the change being shipped.
- Never claim a change is done unless the report file and JSONL records exist.
- If code exists without matching tracking files, stop and surface the mismatch.
- If tracking exists without corresponding code, state that explicitly.
