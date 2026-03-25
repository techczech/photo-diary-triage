# PDT-2026-03-25-006 Tooltip hover restoration and grouped escape hardening report

- item ID: PDT-2026-03-25-006
- summary of what changed:
  - hardened grouped-review section return by switching section scroll restoration to a deferred request/revision path instead of a fragile direct state flip
  - changed grouped section restore scrolling to use top anchoring rather than animated center anchoring
  - replaced permanently visible shortcut chips with hover-only chips while avoiding the earlier popover-based layout path
- files changed:
  - `Sources/PhotoDiaryTriage/AppState.swift`
  - `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
  - `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
  - `APP_RELEASE.env`
- verification performed:
  - `swift build`
  - `swift test`
- known gaps or follow-up items:
  - grouped escape needs user validation in a real interaction loop because the blank-space issue was intermittent
  - hover-only hint chips still need real-app confirmation on all toolbar and review surfaces
- shipped release version: 0.1.45
- shipped feature slug: tooltip-hover-restoration-and-grouped-escape-hardening
