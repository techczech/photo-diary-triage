# Archive browsing includes Trips and Unorganised Folders

The Archive's Timeline and Contact Sheet show both manifest-backed Trips and physical
Unorganised Folders. A year filters the current view. Opening an Unorganised Folder browses
its photos without changing files; organising it as a Trip is a separate explicit action.
This preserves immediate access to the historical collection without inventing diary
structure that is not present on disk.

## Considered options

- **Show only Trips** was rejected because much of the historical Archive predates the
  consistent Trip and Walk structure.
- **Infer months, Trips, and Walks from folder depth or a 2016 cut-off** was rejected because
  the earlier hierarchy varies and the transition date is approximate.
- **Restore the raw folder tree as the primary browser** was rejected because Timeline and
  Contact Sheet provide one consistent photographic browsing surface across organised and
  unorganised material.

## Consequences

- Manifests remain the authority for whether an entry is a Trip or Walk.
- Unorganised Folder summaries are derived and rebuildable; they do not become canonical
  diary records.
- The locked interaction and visual design is
  `design/archive-0.7.0-mockup/` at commit `b1f9cb8`.
