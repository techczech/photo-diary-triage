# PDT-2026-03-24-014 Linting and Version Automation

## Status

- Current status: `draft`
- Priority: P3
- Target release version: TBD
- Target feature slug: `linting-and-versioning`

## User Request

Add SwiftLint for code style enforcement and a version bump script to automate APP_RELEASE.env updates.

## Constraints

- SwiftLint config should be minimal — default rules plus force-unwrap and file-length warnings.
- Version bump script must update both version and build number fields.
- Neither should block development workflow (warnings, not errors, for initial rollout).

## Implementation Intent

- Add `.swiftlint.yml` with minimal config.
- Add SwiftLint as a build phase or pre-commit hook.
- Create `scripts/bump_version.sh` that:
  - Reads current version/build from `APP_RELEASE.env`.
  - Increments build number (and optionally version).
  - Writes updated values back.
  - Optionally commits the change.

## Test Conditions

- `swiftlint lint` runs without errors on current codebase (warnings acceptable).
- `bump_version.sh` correctly increments build number.

## Success Criteria

- Code style issues are surfaced automatically.
- Version bumping is a single command instead of manual file editing.
