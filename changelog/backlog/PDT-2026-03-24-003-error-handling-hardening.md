# PDT-2026-03-24-003 Error Handling Hardening

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: TBD
- Target feature slug: `error-handling-hardening`

## User Request

Fix `try!` crash points at app init and add graceful degradation for database and cache failures.

## Constraints

- App must not crash if SQLite database or preview cache directory can't be created.
- Must handle disk full, permission errors, and corrupted database scenarios.
- User must be informed of the problem, not silently degraded.

## Implementation Intent

- Replace `try!` at `AppState.swift:53-54` with `do/catch`.
- On SessionStore failure: present user-facing error with option to reset or choose new location.
- On PreviewStore failure: fall back to no-cache mode with warning.
- Add `DateFormatter` thread safety (use `ISO8601DateFormatter` or serial queue).

## Test Conditions

- App launches without crash when database path is unwritable.
- App launches without crash when cache directory is unwritable.
- User sees an actionable error message in failure cases.

## Success Criteria

- Zero `try!` or force-unwrap on fallible initialization paths.
- App degrades gracefully rather than crashing on storage failures.

## Normalization Note

- The requested startup hardening shipped as part of `PDT-2026-03-24-016`.
- `AppState` now uses recoverable startup error handling and preview-cache fallback instead of launch-time `try!`.
- This item stays open only for explicit user approval of the normalized tracking state.
