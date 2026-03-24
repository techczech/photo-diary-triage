# PDT-2026-03-24-006 Silent Failure Logging

## Status

- Current status: `draft`
- Priority: P1
- Target release version: TBD
- Target feature slug: `silent-failure-logging`

## User Request

Add structured logging for currently swallowed errors in thumbnail generation, metadata extraction, and other `try?` sites.

## Constraints

- Use `os_log` / `Logger` (system framework, no external deps).
- Logging must not impact UI performance.
- Log levels should be appropriate (error for failures, debug for expected fallbacks).

## Implementation Intent

- Add `Logger` instances to `PreviewStore`, `MetadataExtractor`, `SessionStore`, `ImportCoordinator`.
- Replace bare `try?` with `do { try ... } catch { logger.error(...) }` at key sites.
- Log thumbnail generation failures with file path and error.
- Log metadata extraction failures with file path and reason.
- Log session store operations that silently fail.

## Test Conditions

- Corrupt or unsupported file triggers a log entry (verifiable via Console.app).
- No performance regression for normal operations.

## Success Criteria

- All `try?` sites in critical paths either log the error or have explicit justification for silence.
