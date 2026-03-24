# PDT-2026-03-24-007 Concurrent File Imports

## Status

- Current status: `draft`
- Priority: P1
- Target release version: TBD
- Target feature slug: `concurrent-file-imports`

## User Request

Parallelize file import operations using TaskGroup to improve throughput on SSDs.

## Constraints

- Must maintain correct verification (each file verified after copy).
- Must handle errors per-file without aborting the entire batch.
- Concurrency limit must be configurable or sensible default (4-8).
- Must update progress UI as files complete (ties to PDT-2026-03-24-010).

## Implementation Intent

- Replace sequential file copy loop in `ImportCoordinator` with `TaskGroup`.
- Set default concurrency limit to 4 parallel copies.
- Collect per-file results (success/failure) and report aggregate.
- Ensure manifest generation still happens after all copies complete.

## Test Conditions

- Import of 20+ files completes faster than sequential baseline.
- Single file failure does not abort remaining imports.
- All successfully imported files pass verification.

## Success Criteria

- Measurable speedup on typical SSD import (50+ files).
- No data corruption or missed files.
