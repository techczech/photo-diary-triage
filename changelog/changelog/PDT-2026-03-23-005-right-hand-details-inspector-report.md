# PDT-2026-03-23-005 Right-Hand Details Inspector Report

## Summary Of What Changed

- Added a collapsible right-hand inspector column to the main detail surface.
- Added visible show/hide controls in the header and inside the inspector itself.
- Inspector now shows folder/session summary details for the currently inspected browser node.
- Inspector now shows metadata for the focused or selected photo, including file details, capture info, dimensions, camera/lens, coordinates, and RAW companion counts.
- Follow-up build `0.1.15` widened the default app window and switched the detail region to an `HSplitView` so the inspector is visibly present in the default packaged layout.
- Follow-up build `0.1.16` added a persistent collapsed rail so the inspector can be reopened after being hidden.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `changelog/backlog/PDT-2026-03-23-005-right-hand-details-inspector.md`

## Verification Performed

- `swift build`
- `bash scripts/build_app_bundle.sh`
- verified the rebuilt bundle carries release metadata `0.1.16 / details-inspector-toggle`

## Known Gaps Or Follow-Up Items

- This feature still needs user review in the running app.
- `swift test` remains blocked by the local macOS CLT/XCTest issue.

## Shipped Release

- Version: `0.1.16`
- Feature slug: `details-inspector-toggle`
