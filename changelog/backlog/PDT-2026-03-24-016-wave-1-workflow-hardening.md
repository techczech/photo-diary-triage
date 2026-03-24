# PDT-2026-03-24-016 Wave 1 Workflow Hardening

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.17`
- Target feature slug: `wave-1-workflow-hardening`

## User Request

Implement the deferred-toolchain refactor wave that can ship before full Xcode is installed: startup hardening, initial workflow extraction, lifecycle validation, import progress, and logging.

## Constraints

- Do not depend on `swift test` while the machine is still on incomplete Command Line Tools.
- Preserve the SSD-first selective-import workflow and existing UI behavior.
- Keep archive browsing in `AppState` for now; only extract the workflow seams.
- Track the implementation in repo files before presenting it as complete.

## Implementation Intent

- Replace startup `try!` storage/cache initialization with graceful fallback and user-visible recovery alerts.
- Add protocol seams for session persistence, preview caching, import coordination, and settings persistence.
- Extract `SessionManager`, `ImportWorkflow`, and `SelectionManager`.
- Add validated lifecycle transitions and route import/cleanup selection state through them.
- Surface import progress through `AppState` and the footer UI.
- Add structured logging to the storage, preview, metadata, and import paths.
- Add `.tmp-home/` and `dist/` to `.gitignore` so milestone commits stay focused.

## Test Conditions

- `swift build` succeeds under the current non-Xcode environment.
- Startup no longer force-crashes on persistent store or preview cache setup failures.
- The UI can present a startup alert and a reset action when persistent session storage fails.
- Import progress is available to the UI while import work is running.

## Success Criteria

- Wave 1A, 1B, and Wave 2 groundwork are implemented without waiting for full Xcode.
- The codebase now has smaller workflow seams and no launch-time `try!` on storage/cache setup.
- The repo tracking and release metadata reflect this implementation batch.
