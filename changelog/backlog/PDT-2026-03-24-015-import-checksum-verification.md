# PDT-2026-03-24-015 Import Checksum Verification

## Status

- Current status: `awaiting_user_review`
- Priority: P3
- Target release version: `0.2.33`
- Target feature slug: `import-checksum-verification`

## User Request

Add optional SHA-256 checksum verification for imported files to catch corruption beyond size-only checks.

## Constraints

- Must be opt-in (default remains size-only for speed).
- Must not block the UI during checksum computation.
- Must work for both primary and companion (RAW) files.

## Implementation Intent

- Add `verificationMode` setting to `AppSettings`: `.sizeOnly` (default) or `.checksum`.
- Implement SHA-256 computation using `CryptoKit`.
- Compare source and destination checksums after copy.
- Report checksum mismatches as import errors with file path details.
- Add toggle in Settings view.

## Test Conditions

- Size-only mode works as before (no regression).
- Checksum mode detects a deliberately corrupted copy.
- Checksum computation does not block the main thread.

## Success Criteria

- Users who want extra safety can enable checksum verification.
- Corrupted copies are detected and reported.
