# PDT-2026-03-24-004 Testing Expansion

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.26`
- Target feature slug: `testing-expansion`

## User Request

Expand test coverage beyond the current 7 service-layer tests to cover persistence, selection, lifecycle, and import workflows now that full-Xcode local test execution is available.

## Constraints

- Depends on PDT-2026-03-24-001 (test bootstrap) being unblocked.
- Depends partially on PDT-2026-03-24-002 (AppState decomposition) for selection/lifecycle testability.
- Tests must use deterministic fixtures and temp directories (per existing pattern).
- No mocking of the database — use real SQLite with temp paths.

## Implementation Intent

- **SessionStore tests:** save, load, upsert, migration, recovery from corrupted DB.
- **Lifecycle state transition tests:** valid transitions succeed, invalid transitions rejected.
- **Selection logic tests:** multi-select, shift-click range, keyboard navigation.
- **Import workflow tests:** file copy, size verification, collision handling, error paths.
- **Keyboard shortcut scope tests:** shortcuts fire only in correct focus states (DESIGN.md requirement).

## Test Conditions

- Each new test category has at least 3 tests covering happy path, edge case, and error case.
- All tests pass in `swift test`.

## Success Criteria

- Test count increases from 7 to at least 25.
- SessionStore, lifecycle, and import paths are covered.
