# App Agents

Use this file for app-code decisions under `Sources/PhotoDiaryTriage/`.

## Absolute Priorities

- The app must be fast enough for real triage on large sessions.
- The review grid must be usable at a glance: no overlap, clear spacing, subtle borders, obvious selection/focus states.
- Selection must work correctly with mouse and keyboard, including plain click, Shift-click, Command-click, range extension, and keyboard movement.
- Keyboard-first triage is mandatory. Frequent review actions must work without touching the mouse.
- Preview and compare are core decision surfaces. They must support fast inspection and direct import decisions.

## Interaction Rules

- Grid review stays the primary review surface.
- Compare is a secondary mode launched from the current selection or burst/cluster context.
- Shortcut behavior must be scoped to the active review surface and must not leak into forms, sheets, or unrelated controls.
- Destructive actions stay behind explicit confirmation.
- Preserve SSD-first selective import and archive-preview visibility before commit.

## Performance Rules

- Treat performance as a product feature, not cleanup work.
- Prioritize visible thumbnails and nearby content before off-screen work.
- Avoid rebuilding archive/navigation structures unnecessarily.
- Prefer bounded concurrency over unbounded background work.
