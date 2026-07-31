# Walkfolio 0.7.0 Archive mockup

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
- Search filters the same Trip collection in either view.
- All Trips groups the current view by year.
- A year is a filter over the current view, not a separate Archive destination.
- Choosing a year preserves Timeline or Contact Sheet and narrows it to one year band.
- Timeline uses vertical arrow navigation.
- Contact Sheet uses two-dimensional arrow navigation.
- Enter opens the selected Trip summary; Escape closes transient surfaces.
- Global search, command palette, contextual actions, inspector, settings, and shortcut
  guide follow the estate-wide keyboard contract.

## Review states

- Populated Timeline.
- Populated Contact Sheet.
- Search results.
- No-results state with a recovery action.
- Trip summary panel.
- Compact-width layout.
- All Trips with several year bands.
- A selected year in both Timeline and Contact Sheet.
