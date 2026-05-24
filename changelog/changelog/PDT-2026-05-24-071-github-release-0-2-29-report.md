# PDT-2026-05-24-071: GitHub release 0.2.29

## Summary

- Published GitHub release `v0.2.29`.
- Release target commit: `98a41865f6b700cde2515dbf3f620642e838cb6f`.
- Release URL: <https://github.com/techczech/photo-diary-triage/releases/tag/v0.2.29>
- Uploaded app asset: `PhotoDiaryTriage-0.2.29-macos.zip`.

## Files Changed

- `changelog/backlog/PDT-2026-05-24-071-github-release-0-2-29.md`
- `changelog/changelog/PDT-2026-05-24-071-github-release-0-2-29-report.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `gh auth status`
  - authenticated as `techczech`
- `./scripts/build_app_bundle.sh`
  - rebuilt `dist/PhotoDiaryTriage.app`
- `ditto -c -k --keepParent dist/PhotoDiaryTriage.app dist/PhotoDiaryTriage-0.2.29-macos.zip`
  - packaged app zip asset
- `shasum -a 256 dist/PhotoDiaryTriage-0.2.29-macos.zip`
  - `5b7373d278ef48b2a2a94cd97c836aac2ff38d28b4cd417c9b5b6393cff72c04`
- `gh release view v0.2.29`
  - release exists
  - not draft
  - not prerelease
  - target commit is `98a41865f6b700cde2515dbf3f620642e838cb6f`
  - uploaded asset exists
  - GitHub asset digest matches local SHA-256
- `git ls-remote --tags origin v0.2.29`
  - remote tag points to `98a41865f6b700cde2515dbf3f620642e838cb6f`

## Known Gaps Or Follow-Up Items

- User should test `0.2.29` on the MacBook Air with its local OneDrive path and SD card workflow.
- OneDrive cloud upload completion is still not verified inside the app.

## Shipped Release

- APP_VERSION: 0.2.29
- APP_BUILD: 106
- APP_FEATURE_SLUG: travel-mode-sync-cloud-workflow
