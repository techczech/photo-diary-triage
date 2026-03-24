# Agents

This is the canonical agent-instructions file for this repo. Always read this file before planning, implementing, reviewing, or reporting status.

## Purpose

This document defines the agent responsibilities for evolving Photo Diary Triage without drifting from the SSD-first selective-import workflow or from the UX contract in [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md).

## Required Workflow

These rules apply before any work starts and before any work is declared done.

- Always check both [changelog/backlog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog.jsonl) and [changelog/changelog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/changelog.jsonl) before planning, implementing, reviewing, or reporting progress.
- Always read the nested [changelog/AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/AGENTS.md) before creating or updating tracking records.
- Never start work without confronting the current backlog state and changelog state.
- Never claim something is implemented, fixed, reviewed, or approved unless that status is reflected consistently in both backlog/changelog and matches the actual code.
- If the code, backlog, and changelog disagree, stop and surface the mismatch explicitly before continuing.
- Every new user request must be reflected by a new spec markdown file in [changelog/backlog/](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog/) before it is treated as active work.
- Every spec file must be logged by appending a record to [changelog/backlog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/backlog.jsonl).
- Every implemented change must be reflected by a report markdown file in [changelog/changelog/](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/changelog/) before it is presented as completed or ready for review.
- Every report file must be logged by appending a record to [changelog/changelog.jsonl](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/changelog/changelog.jsonl).
- Every implemented change must increment [APP_RELEASE.env](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/APP_RELEASE.env) and set a current `APP_FEATURE_SLUG`.
- A backlog item is not done until the user explicitly approves it.
- Chat is never the sole system of record for work. The repository tracking files are authoritative.

## Product Agent

Owns product clarity and workflow consistency.

- Protect the core rule that triage happens against the source SSD and only selected files are imported.
- Keep destructive actions behind explicit user confirmation.
- Ensure new features preserve durable manifest generation and local-first behavior.
- Never approve or implement a design change without explicit user approval first.
- Enforce the design-governance document as authoritative for UX behavior.
- Enforce the backlog/changelog workflow before any product decision is treated as active or complete.

## App Architecture Agent

Owns macOS app structure, state flow, and module boundaries.

- Keep the app centered on `ImportSession`, `MediaItem`, grouping models, archive planning, and cleanup state.
- Prefer service boundaries for metadata extraction, grouping, import, manifests, previews, and persistence.
- Keep external integrations behind protocols until they are intentionally implemented.

## Persistence Agent

Owns SQLite and durable records.

- Treat SQLite as the operational store for active sessions.
- Ensure Markdown and JSONL exports remain readable and sufficient for long-term reference.
- Preserve forward migration paths for schema changes.
- Ensure settings, sessions, and backup/export state are durable and recoverable.
- Treat backlog and changelog accuracy as part of durable project state, not optional documentation.

## Safety Agent

Owns import verification and cleanup rules.

- Source folders remain untouched during triage.
- Imported files must be verified before cleanup is possible.
- Cleanup may only target files already imported from the SSD and explicitly approved for cleanup.

## UX Agent

Owns review ergonomics.

- Prioritize fast thumbnail browsing, clear status messaging, and low-friction selection.
- Preserve grid-first final review as a non-negotiable default.
- Enforce UI and keyboard parity for frequent actions.
- Ensure all popups and transient surfaces are closable.
- Keep archive destination previews visible before commit.
- Keep backup confirmation, settings persistence, and recovery state obvious to the user.
- Never present UX work as done unless the related backlog/changelog entries are updated and consistent with the shipped behavior.

## Testing Agent

Owns confidence in the core workflow.

- Cover grouping boundaries, archive path planning, collision handling, manifest content, and cleanup gating.
- Prefer deterministic fixtures and temp-directory tests for file operations.
- Add regression tests before changing lifecycle rules or archive naming.
- Verify implemented behavior against [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md), not just against code-level expectations.
- Treat shortcut scope, closable modals, persistence, backup flows, and selection robustness as required verification areas.
- Verify that backlog/changelog claims match the code before signing off on any change.
