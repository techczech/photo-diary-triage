# Walkfolio 0.7.0 Archive mockup

## Design lock

Dominik approved the mixed Archive design on 2026-07-31. This interactive mockup and
`docs/adr/0003-archive-browse-includes-unorganised-folders.md` govern production
implementation.

## Purpose

Test whether Timeline and Contact Sheet work as two useful readings of one indexed Archive.

## Source designs

- `references/timeline-reference.png`
- `references/contact-sheet-reference.png`

## Interaction contract

- Timeline is the initial view.
- Contact Sheet is an alternate view chosen from a visible control beside the page title.
- The chosen view persists locally.
- Selection persists when the view changes.
- Search filters the same Archive entries in either view.
- The complete Archive groups the current view by year.
- A year is a filter over the current view, not a separate Archive destination.
- Choosing a year preserves Timeline or Contact Sheet and narrows it to one year band.
- Recognised Trips and unorganised folders appear in the same views with distinct labels and
  actions.
- Unorganised folders open without changing files; organisation is a separate explicit
  action.
- Timeline uses vertical arrow navigation.
- Contact Sheet uses two-dimensional arrow navigation.
- Enter opens the selected entry summary; Escape closes transient surfaces.
- Global search, command palette, contextual actions, inspector, settings, and shortcut
  guide follow the estate-wide keyboard contract.

## Review states

- Populated Timeline.
- Populated Contact Sheet.
- Search results.
- No-results state with a recovery action.
- Trip and unorganised-folder summary panels.
- Compact-width layout.
- The complete Archive with several year bands and mixed entry types.
- A selected year in both Timeline and Contact Sheet.
