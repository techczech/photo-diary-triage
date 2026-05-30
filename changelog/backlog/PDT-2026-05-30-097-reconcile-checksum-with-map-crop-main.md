# PDT-2026-05-30-097 Reconcile checksum verification with map/crop main

## Item ID

PDT-2026-05-30-097

## Title

Reconcile checksum verification with map/crop main

## User Request Summary

Reconcile the two divergent local and remote versions first, keeping the useful local checksum verification work while preserving the latest upstream crop, performance, and map/location work.

## Constraints

- Base the result on latest `origin/main` (`0.2.51`, build `128`).
- Preserve local checksum import verification behavior from the divergent local branch.
- Preserve local archive-intelligence review record if it still helps planning.
- Keep append-only backlog/changelog JSONL history valid.
- Do not overwrite remote crop, map, or responsiveness work.
- Build, test, install, and name the exact version for user testing.

## Implementation Intent

- Reapply checksum verification onto latest main.
- Keep `Size Only` as default and `SHA-256 Checksum` as optional stronger verification.
- Ensure import, settings, and tests compile with latest map/crop code.
- Reconcile release metadata as a new build.
- Record the reconciliation as a changelog report.

## Test Conditions

- JSONL tracking validates line-by-line.
- Focused import checksum tests pass.
- Full `swift test` is attempted and results are recorded.
- `./scripts/build_app_bundle.sh` builds the reconciled app.
- Installed app reports the reconciled `APP_VERSION`.

## Success Criteria

- Latest map/crop app behavior remains present.
- Checksum verification can be selected in Settings and used during copy verification.
- Reconciled app is installed and launched.
- No uncommitted reconciliation work remains.

## Current Status

approved_for_implementation

## Target Release Version

0.2.52

## Target Feature Slug

reconcile-checksum-map-crop
