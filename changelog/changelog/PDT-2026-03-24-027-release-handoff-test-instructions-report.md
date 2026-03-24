# PDT-2026-03-24-027 Release Handoff Test Instructions Report

## Summary Of What Changed

- Added a new root-level handoff rule to [AGENTS.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/AGENTS.md) requiring every future implementation handoff to name the exact `APP_VERSION` to test, describe the intended user-visible functionality in that version, and explicitly ask the user to test it.
- Recorded the reason for the rule: `0.1.27` was the instruction/backlog normalization checkpoint, while the review interaction rescue shipped in `0.1.28`, so future handoffs need to be version-explicit.

## Files Changed

- `AGENTS.md`
- `APP_RELEASE.env`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`
- `changelog/backlog/PDT-2026-03-24-027-release-handoff-test-instructions.md`

## Verification Performed

- `swift build`
- `swift test`

## Known Gaps Or Follow-Up Items

- This change only updates the instruction policy; it does not alter app behavior.
- The actual review-rescue features still need user confirmation against app version `0.1.28`.

## Shipped Release

- Version: `0.1.29`
- Feature slug: `release-handoff-test-instructions`
