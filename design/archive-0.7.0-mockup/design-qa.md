# Walkfolio Archive 0.7.0 design QA

**Findings**

- No actionable P0, P1 or P2 differences remain.
- The implementation keeps the source designs’ macOS structure, information density,
  restrained colour system, persistent year navigation, wide Timeline rows and image-led
  Contact Sheet while allowing Trips and unorganised folders to share the same views.
- The photographs intentionally differ from the ideation references. The implementation uses resized copies of photographs from Dominik’s local Archive, as requested, and does not use generated cover photography.

**Required fidelity surfaces**

- Fonts and typography: The implementation uses the macOS system font stack with the same compact hierarchy as the references. Titles, metadata and small navigation labels remain legible at both tested widths without unintended wrapping.
- Spacing and layout rhythm: The title bar, year sidebar, content header, view switcher, Timeline rows and four-column Contact Sheet retain the proportions and alignment of the references. The 820-pixel test keeps the primary Archive controls and readable Timeline rows without overlap.
- Colours and visual tokens: The implementation matches the neutral macOS palette, hairline separators, blue selection state and low-contrast metadata treatment. There are no decorative gradients or ungrounded brand colours.
- Image quality and asset fidelity: All nineteen covers are local Archive photographs, resized to a maximum of 1,200 pixels and cropped with `object-fit: cover`. They remain sharp at both row and tile sizes.
- Copy and content: Archive, Trips, Walks, Timeline and Contact Sheet follow the product
  vocabulary. The complete destination is `Archive`, because it also contains physical
  folders that have not become Trips. `Unorganised folder` labels that condition without
  inventing a diary entity. Singular and plural year counts are correct. “Newest first”
  uses explicit chronological keys rather than comparing human-readable date strings.

**Source visual truth**

- `references/timeline-reference.png` — 1,487 × 1,058 pixels.
- `references/contact-sheet-reference.png` — 1,487 × 1,058 pixels.

**Implementation evidence**

- Local prototype: `http://127.0.0.1:4173/`.
- `design-qa/mixed-archive-all-timeline-958x907.png` — the complete mixed Archive.
- `design-qa/unorganised-folders-2013-timeline-958x907.png` — the same Timeline filtered
  to a historical folder-only year.
- `design-qa/unorganised-folders-2013-contact-sheet-958x907.png` — the same year with the
  Contact Sheet view preserved.
- `design-qa/all-trips-timeline-1440x1024.png` — 1,440 × 1,024 pixels.
- `design-qa/all-trips-contact-sheet-1440x1024.png` — 1,440 × 1,024 pixels.
- `design-qa/year-filter-2024-contact-sheet-1440x1024.png` — 1,440 × 1,024 pixels.
- `design-qa/all-trips-compact-820x900.png` — 820 × 900 pixels.
- CSS viewports: 1,440 × 1,024 and 820 × 900.
- Device scale factor: 1.
- Density normalization: The full-view comparison canvases place each source and implementation capture in a 700 × 920 pixel panel using aspect-preserving Lanczos downsampling.
- States: the complete Archive grouped by year in Timeline and Contact Sheet; a historical
  year containing only unorganised folders; entry-type filtering; view continuity across
  year filters; Trip and folder dialogs; compact Timeline; search results; command palette;
  Settings.

**Full-view comparison evidence**

- `design-qa/timeline-comparison.png` compares the Timeline reference and rendered Timeline in one image.
- `design-qa/contact-sheet-comparison.png` compares the Contact Sheet reference and rendered Contact Sheet in one image.
- The combined comparisons confirm that the two views read as alternative presentations of
  the same Archive rather than separate destinations. The mixed-entry captures confirm that
  the geometry also works for physical folders which have no Walk count.

**Focused region comparison evidence**

- No additional crop was needed. At the original 1,440 × 1,024 captures, the toolbar, switcher, selection outline, metadata, image crops and row/tile spacing are readable. Interaction states were checked directly in the rendered prototype.

**Interaction and runtime checks**

- Timeline and Contact Sheet switching preserves the selected Trip.
- The most recently used view persists through reload.
- The complete Archive contains 10 recognised Trips and 9 unorganised folders across five
  years in both views.
- Choosing 2013 keeps the active view and shows nine unorganised folders without a month or
  Trip layer.
- Switching to Contact Sheet while 2013 is selected keeps the year filter and shows nine
  folder tiles.
- Opening an unorganised folder presents `Open Photos` and `Organise as a Trip…` as separate
  actions; the folder description states that browsing makes no file changes.
- The `Trips` and `Unorganised folders` filters operate over the same Archive and retain the
  selected view.
- Choosing 2024 keeps Contact Sheet active and shows only the 2024 year band.
- Switching to Timeline while 2024 is selected keeps the year filter.
- Returning to All keeps Timeline active and restores all five year bands.
- Search for “Prague” returns the single matching Trip and keeps the active view.
- Arrow keys move selection and Return opens the selected Trip.
- `⌘1` opens Timeline and `⌘⇧P` opens the command palette.
- Settings opens from the title bar.
- The production build and Sites packaging tests pass.
- A clean reload produced the complete Archive without a current browser warning or error.

**Comparison history**

- Current P1 finding: “All Trips” excluded historical folders that do not yet have the
  Walkfolio Trip and Walk structure, and pre-2016 subfolders cannot safely be interpreted as
  months.
  Fix: Renamed the destination to `Archive`, added explicit Trip and unorganised-folder
  entry types, kept years as filters, and gave folders read-only browsing plus a separate
  organisation action. The approximate 2016 transition is not encoded as a parser rule.
  Post-fix evidence: the three 958 × 907 mixed-Archive captures and the browser interaction
  checks above.
- Earlier P1 finding: Trips and years looked like separate destinations, and most year choices produced empty mock data.
  Fix: Renamed the complete Archive view to “All Trips”, labelled years as filters, grouped both views into year bands, and added representative local Archive photographs for five years.
  Post-fix evidence: `design-qa/all-trips-contact-sheet-1440x1024.png` shows five year bands; `design-qa/year-filter-2024-contact-sheet-1440x1024.png` shows the same Contact Sheet narrowed to 2024.
- Earlier P2 finding: “Newest first” compared display-date strings, which produced a visibly incorrect order.
  Fix: Added explicit ISO-like sort keys and sorted by those keys.
  Post-fix evidence: `design-qa/timeline-1440x1024.png` and `design-qa/contact-sheet-1440x1024.png` show November through April in descending order.
- Earlier P2 finding: The status bar displayed “1 Trips” for a one-result search.
  Fix: Added singular and plural Trip labels.
  Post-fix evidence: Browser-rendered “Prague” search reported one Trip.

**Implementation checklist**

- Keep the high-fidelity prototype available for design review.
- The combined Timeline, Contact Sheet, Trip, and Unorganised Folder design was locked by
  Dominik on 2026-07-31.
- Production SwiftUI work must cite the locked mockup and
  `docs/adr/0003-archive-browse-includes-unorganised-folders.md`.

**Follow-up polish**

- No P3 refinements are required before review.

final result: passed
