# Archive layout: Trips are month-level sibling folders, Walks inside them

The Archive is reorganised around Trips (named groups of Walks — see CONTEXT.md). A Trip is
a physical folder at the month level under the year: the plain month folder (`06-June`) is
the **default Trip** for that month's standalone Walks, and named Trips
(`06-June-Lake-District-Trip`, keyed by start month) sit **beside** it as siblings — never
nested inside it. Walk folders (`02-Sun-Walk-in-Blenheim`, day + weekday + slug) live
directly inside their Trip; there is exactly one folder shape, and moving a Walk between
Trips is a single sibling-folder move.

Layout: `YYYY / MM-MonthName[-Trip-Slug] / DD-Ddd-Walk-Slug / YYYY-MM-DD-slug-NNN.ext`

## Considered options

- **Trip folders nesting Walk folders under `YYYY/MM/`** (uniform deep nesting): rejected —
  the dominant case (a standalone walk) would carry a redundant double folder, and the month
  level already provides the grouping.
- **Trips as manifest-only objects, Walks as the only folders**: rejected — it was motivated
  by the assumption that OneDrive re-uploads moved files, which is false: the official macOS
  client is a File Provider replicated extension, and local moves sync as server-side
  metadata moves (no content re-upload). With moves cheap, Finder-legible Trip folders win.

## Consequences

- The existing `YYYY/MM/YYYY-MM-DD-walk-slug` archive must be migrated (folder renames +
  moves + manifest path rewrites); file names (`YYYY-MM-DD-slug-NNN.ext`) are unchanged and
  carry the full date because folder names no longer do.
- The app must rewrite recorded relative paths in manifests whenever it moves a Walk.
- Cross-month Trips are keyed by start month; their later Walks' day-first folder names
  missort within the Trip. Accepted as rare and humanly readable (weekday token makes it
  obvious).
- The weekday token is user-configurable in Settings (English abbreviations by default) but
  fixed per archive, not per machine locale.
- "Walk" and "Trip" are canonical model/manifest terms (see CONTEXT.md); only their UI
  display labels are user-configurable.
