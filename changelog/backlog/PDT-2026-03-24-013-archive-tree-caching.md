# PDT-2026-03-24-013 Archive Tree Caching

## Status

- Current status: `draft`
- Priority: P3
- Target release version: TBD
- Target feature slug: `archive-tree-caching`

## User Request

Cache the archive sidebar tree and precompute item counts instead of rebuilding on every navigation.

## Constraints

- Cache must invalidate after imports complete or on manual refresh.
- Must not show stale data after a successful import.
- Sidebar counts must stay accurate.

## Implementation Intent

- Cache `archiveYearFolders` and archive node tree after first build.
- Invalidate cache when `ImportCoordinator` completes an import.
- Add a manual "Refresh Archive" action for edge cases.
- Precompute and cache sidebar item counts at session load and regrouping time.

## Test Conditions

- Sidebar loads faster on repeated navigation.
- Cache invalidates correctly after import.
- Manual refresh forces a fresh filesystem scan.

## Success Criteria

- No redundant filesystem scans during normal sidebar browsing.
