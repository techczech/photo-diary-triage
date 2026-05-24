# PDT-2026-05-24-071: GitHub release 0.2.29

## User Request Summary

- Publish the current `0.2.29` app release to GitHub so it can be installed on the MacBook Air.

## Constraints

- Use current `APP_RELEASE.env` release metadata.
- Do not change app behavior.
- Verify repository is clean and pushed before release.
- Write GitHub release text to a file before creating the release.
- Publish tag and release for `v0.2.29`.
- Upload a zipped macOS app bundle asset.

## Implementation Intent

- Confirm the current release commit and GitHub authentication.
- Package `dist/PhotoDiaryTriage.app` as `PhotoDiaryTriage-0.2.29-macos.zip`.
- Push the local release commit and tracking commit.
- Create GitHub release `v0.2.29` with release notes and app asset.
- Record release URL and verification evidence in a changelog report.

## Test Conditions

- `gh release view v0.2.29` returns the release.
- Release points at the current pushed commit.
- Release asset exists.
- Remote tag `v0.2.29` points at the release commit.

## Success Criteria

- GitHub release `v0.2.29` is published.
- MacBook Air can download `PhotoDiaryTriage-0.2.29-macos.zip`.
- Release notes mention travel OneDrive photo-log sync.

## Current Status

- status: approved_for_implementation

## Target Release

- APP_VERSION: 0.2.29
- APP_BUILD: 106
- APP_FEATURE_SLUG: travel-mode-sync-cloud-workflow
