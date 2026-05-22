# Inspector Workflow Redesign Meta

## Request

- Redesign the PhotoDiaryTriage inspector because the copied-log workflow is confusing.
- Make the copied archive folder an obvious link inside the app.
- Use modern macOS patterns and cognitive walkthroughs.

## Date

- 2026-05-22

## Target Surface

- macOS SwiftUI inspector pane for photo-log workflow state.

## Implementation Target

- Native SwiftUI in the existing PhotoDiaryTriage app.

## Inputs

- User screenshot: `/Users/dominiklukes/Library/CloudStorage/OneDrive-Nexus365/Screenshots/MacOS Screenshots/CleanShot 2026-05-22 at 09.17.56.png`
- Current app source under `Sources/PhotoDiaryTriage/`
- NN/g cognitive walkthrough article: `https://www.nngroup.com/articles/cognitive-walkthroughs/`

## Constraints

- Preserve copy verification, manual backup confirmation, and source-cleanup gating.
- Keep archive path visible and clickable.
- Keep S/C/X and log-membership semantics unchanged.
- Prefer native macOS layout, controls, iconography, and Finder-oriented language.

## Image Workflow Note

- This plan records the design intent and model prompt for the image-to-design workflow.
- Production implementation proceeds directly in SwiftUI because the current task is a native app change and the required outcome is a working inspector.
