# PDT-2026-05-23-069: GitHub release 0.2.28

## User Request Summary

- Publish the current app release to GitHub.

## Constraints

- Use current `APP_RELEASE.env` release metadata.
- Do not change app behavior.
- Verify repository is clean and pushed before release.
- Write GitHub release text to a file before creating the release.
- Publish tag and release for `v0.2.28`.

## Implementation Intent

- Confirm current commit and GitHub release state.
- Package `dist/PhotoDiaryTriage.app` as a zip asset.
- Create GitHub release `v0.2.28` with release notes and asset.
- Record release URL in changelog report.

## Test Conditions

- `gh release view v0.2.28` returns the release.
- Release points at the current pushed commit.
- Release asset exists.

## Success Criteria

- GitHub release `v0.2.28` is published.
- Release notes mention the compare-action hard-scope safety fix.
- App repo and tracking repo are pushed.

## Current Status

- status: approved_for_implementation

## Target Release

- APP_VERSION: 0.2.28
- APP_BUILD: 105
- APP_FEATURE_SLUG: compare-action-hard-scope
