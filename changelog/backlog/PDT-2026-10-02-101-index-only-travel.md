---
item_id: PDT-2026-10-02-101
title: Index-only archive browsing on the travel Mac
status: shipped_pending_native_check
target_release_version: 0.7.5
target_build: 141
target_feature_slug: index-only-travel
---

# Index-only travel browsing

The approved completion plan requires archive browse/search/map metadata to work from the pinned index. The current catalogue still discovers unorganised folders from the archive tree, and photo grids use FileScanner. This fails when a travel Mac has only the index and thumbnails.

Implement the existing promise without changing the browse interaction: the main archive index records historical folder/photo metadata as well as canonical Walks/Trips; travel catalogue and grids consume only index records. Preserve canonical photo identity, coordinates and image dimensions where available. Historical discovery reads filesystem metadata, not original photo bytes. RAW companions remain grouped with their primary keeper rather than becoming duplicate cards.

Tests use a fresh travel root containing only `_index`, a file-manager spy rejecting archive enumeration, missing originals/folders and a scanner that cannot enumerate originals. Timeline, historical folders, photo grids and FTS must still work. Old index fields remain decodable; damaged generation errors remain explicit. Indexed paths must be archive-relative and must not escape through traversal/symlinks.

Success: index-only fresh-root workflow passes through the actual catalogue and BrowserViewModel loader; full regression suite stays green; signed 0.7.5 build is packaged and recorded. Native/OneDrive verification remains separate while the reviewer is away.

## Implementation checkpoint

The catalogue and BrowserViewModel grid consume only index records in travel mode. Historical discovery on the main machine uses file attributes and preserves case-sensitive directory identity and RAW groups. Canonical photo IDs, dimensions and coordinates are projected; crop families and dimensions survive without crop sidecars. Prepared previews bypass original generation; archive preheat is disabled in travel. The live sidebar uses catalogue nodes; old filesystem tree builders are unreachable.

Full suite: 235 tests passed in 11.341 seconds. Ten new travel regressions cover fresh-root catalogue/grid/search, escaping paths, routine preview policy, case-sensitive grouping and crop family reconstruction. The existing historical test now proves historical rows are indexed while no Trips or Walks are invented. Older field sets remain readable by 0.7.5. Older app versions cannot read the new folder record kind and should be updated on shared machines.

Archive preview/link/crop actions resolve the active folder even when a loaded Photo Log shares the same media ID. Successful archive crops refresh the derived index; crops of crops are reconstructed. Duplicate canonical paths fail while retaining the previous index. Targeted projection holds the archive lock from manifest reads through publication. Archive byte guards reject escaping symlinks even for explicit reads.
