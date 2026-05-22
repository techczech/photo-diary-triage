# Photo Log List Redesign Meta

## Request

- Redesign the photo-log list with the same treatment as the redesigned inspector workflow.

## Date

- 2026-05-22

## Target Surface

- Photo Logs disclosure inside the macOS SwiftUI inspector.

## Implementation Target

- Native SwiftUI in the existing PhotoDiaryTriage app.

## Inputs

- User screenshot: `/Users/dominiklukes/Library/CloudStorage/OneDrive-Nexus365/Screenshots/MacOS Screenshots/CleanShot 2026-05-22 at 10.28.08.png`
- Existing inspector workflow redesign in `design-plans/inspector-workflow-redesign/`

## Constraints

- Keep all existing actions.
- Keep the list compact enough for a narrow inspector.
- Avoid clipped labels and vertically stacked single-letter title fragments.
- Preserve copied-log lock semantics.
