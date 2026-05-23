# PDT-2026-05-23-069: GitHub release 0.2.28

## Summary

- Published GitHub release `v0.2.28`.
- Release target commit: `9911dc2dc94ee57177b129ee71b8d9ab96bab3c1`.
- Release URL: <https://github.com/techczech/photo-diary-triage/releases/tag/v0.2.28>
- Uploaded app asset: `PhotoDiaryTriage-0.2.28-macos.zip`.

## Files Changed

- `changelog/backlog/PDT-2026-05-23-069-github-release-0-2-28.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `gh release view v0.2.28`
  - release exists
  - not draft
  - not prerelease
  - target commit is `9911dc2dc94ee57177b129ee71b8d9ab96bab3c1`
  - uploaded asset exists
- `git ls-remote --tags origin v0.2.28`
  - remote tag points to `9911dc2dc94ee57177b129ee71b8d9ab96bab3c1`
- `shasum -a 256 dist/PhotoDiaryTriage-0.2.28-macos.zip`
  - `192c02ed7d6727534389ca140830bf029fea772ed2c967d2127ce58e9e7f5818`
- `git fetch --tags origin v0.2.28`
  - local tag available

## Known Gaps Or Follow-Up Items

- None for publishing. User should still test `0.2.28` on real photos before trusting destructive source cleanup.

## Shipped Release

- APP_VERSION: 0.2.28
- APP_BUILD: 105
- APP_FEATURE_SLUG: compare-action-hard-scope
