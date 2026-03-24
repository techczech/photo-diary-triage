# PDT-2026-03-24-010 Import Progress Reporting

## Status

- Current status: `awaiting_user_review`
- Priority: P2
- Target release version: TBD
- Target feature slug: `import-progress-reporting`

## User Request

Show per-file progress during imports instead of a single completion message.

## Constraints

- Progress updates must not block the import pipeline.
- UI must remain responsive during import.
- Must work with both sequential and concurrent imports (PDT-2026-03-24-007).

## Implementation Intent

- Add `@Published var importProgress: (current: Int, total: Int)?` to AppState (or ImportWorkflow).
- Update progress after each file completes.
- Show "Importing 12/47..." style message in the status bar.
- Clear progress on completion or cancellation.

## Test Conditions

- Progress updates appear during multi-file import.
- Final status shows success/failure summary.

## Success Criteria

- User sees real-time feedback during imports of 10+ files.

## Normalization Note

- Import progress reporting shipped through `PDT-2026-03-24-016` and is exercised by the expanded workflow tests in `PDT-2026-03-24-004`.
- The stale draft state no longer matches the code and has been normalized here.
