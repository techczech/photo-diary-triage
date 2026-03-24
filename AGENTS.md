# Agents

Read this file before planning, implementing, reviewing, or reporting status.

## Non-Negotiable Rules

- Backlog and changelog must never drift from the code.
- Always check [changelog/backlog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog.jsonl) and [changelog/changelog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/changelog.jsonl) before starting or reporting work.
- Always read [changelog/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/AGENTS.md) before creating or updating tracking files.
- Every new user request needs a spec in [changelog/backlog/](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/) plus a matching `backlog.jsonl` entry before it becomes active work.
- Every implemented change needs a report in [changelog/changelog/](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/changelog/) plus matching JSONL updates before it is presented as done.
- Every implemented change must update [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env).
- If code, backlog, and changelog disagree, surface the mismatch and fix tracking before continuing.

## Product Priorities

- Speed and usability outrank refactors, CI, linting, and internal cleanup.
- Keyboard-driven triage is mandatory.
- Mouse and keyboard selection must both work correctly.
- Preview and compare are decision tools, not optional extras.
- Grid browsing must stay responsive, legible, and non-overlapping.
- Preserve the SSD-first selective-import workflow defined in [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md).

## Where Details Live

- Tracking workflow: [changelog/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/AGENTS.md)
- App implementation priorities: [Sources/PhotoDiaryTriage/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Sources/PhotoDiaryTriage/AGENTS.md)
- Test and verification priorities: [Tests/PhotoDiaryTriageTests/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/Tests/PhotoDiaryTriageTests/AGENTS.md)
- Machine/build environment notes: [_DEVLOG/machineconfig/devsetup_swift_xcode.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/_DEVLOG/machineconfig/devsetup_swift_xcode.md)
