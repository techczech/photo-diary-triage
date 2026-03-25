# PDT-2026-03-25-007 Review grid left-overlap fix report

- item ID: PDT-2026-03-25-007
- summary of what changed:
  - removed horizontal scrolling from the flat review grid so the review pane no longer maintains a horizontal content offset
  - forced the review pane container to fill and clip its own area so focus activation cannot shift content under the sidebar
  - kept the grouped review, tooltip, and escape fixes otherwise unchanged
- files changed:
  - `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
  - `APP_RELEASE.env`
- verification performed:
  - `swift build`
  - `swift test`
- known gaps or follow-up items:
  - grouped-review escape is still partially unresolved and remains a follow-up area
  - this layout regression needs direct user validation in the app because it is interaction-specific
- shipped release version: 0.1.46
- shipped feature slug: review-grid-left-overlap-fix
