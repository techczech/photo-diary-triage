# PDT-2026-03-24-027 Release Handoff Test Instructions

## Status

- Current status: `awaiting_user_review`
- Priority: P0
- Target release version: `0.1.29`
- Target feature slug: `release-handoff-test-instructions`

## User Request

Update `AGENTS.md` so every future implementation handoff names the exact app release version to test, describes the intended user-visible functionality, and explicitly asks the user to test that version.

## Constraints

- Keep the root `AGENTS.md` minimal.
- The instruction must be strong enough to prevent ambiguous “it should be in the app now” reporting.
- The rule must apply whenever new features or fixes are handed off for user verification.
- Tracking must reflect that `0.1.27` was not the review-rescue build; that work shipped in `0.1.28`.

## Implementation Intent

- Add a release-handoff rule to the root `AGENTS.md`.
- Require future completion messages to include the exact `APP_VERSION`, intended behavior to test, and a direct request for user verification.
- Record the mismatch correction in the report so the repo history explains why this rule was added.

## Test Conditions

- The updated `AGENTS.md` explicitly requires version-specific test handoff messaging.
- `swift build` succeeds.
- `swift test` succeeds.

## Success Criteria

- Future handoff messages cannot omit the exact version to test.
- Future handoff messages must describe what the user should expect to work in that version.
- Future handoff messages must explicitly ask the user to test that version.
