# PDT-2026-03-24-008 Gitignore Cleanup

## Status

- Current status: `draft`
- Priority: P1
- Target release version: TBD
- Target feature slug: `gitignore-cleanup`

## User Request

Add `.tmp-home/` and `dist/` to `.gitignore` to stop them polluting `git status`.

## Constraints

- Must not affect any tracked files.
- Must not remove existing `.gitignore` entries.

## Implementation Intent

- Append `.tmp-home/` and `dist/` to the existing `.gitignore` file.

## Test Conditions

- `git status` no longer shows `.tmp-home/` or `dist/` as untracked.

## Success Criteria

- Clean `git status` output after the change.
