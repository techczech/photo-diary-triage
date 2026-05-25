# PDT-2026-05-25-072: Laptop screen fit report

## Summary

- Reduced the main window minimum width so the app can fit inside a 1280-point laptop viewport.
- Reduced sidebar, detail, and inspector minimum widths so the three-pane layout no longer forces horizontal overflow.
- Made the archive header responsive by keeping the full header controls at wide widths and falling back to compact icon controls at narrow widths.
- Added missing `@MainActor` isolation to existing SwiftUI views that call `AppState`, so the app builds under the current Swift toolchain.
- Bumped release metadata to `APP_VERSION=0.2.30`, `APP_BUILD=107`, `APP_FEATURE_SLUG=laptop-screen-fit`.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/PhotoDiaryTriageApp.swift`
- `Sources/PhotoDiaryTriage/ContentView.swift`
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift`
- `Sources/PhotoDiaryTriage/ContentViewSections.swift`
- `Sources/PhotoDiaryTriage/ContentAuxiliaryViews.swift`
- `changelog/backlog/PDT-2026-05-25-072-laptop-screen-fit.md`
- `changelog/backlog.jsonl`
- `changelog/changelog.jsonl`

## Verification Performed

- `swift build`
  - Passed.
- `./scripts/build_app_bundle.sh`
  - Passed.
- `codesign --verify --deep --strict --verbose=2 dist/PhotoDiaryTriage.app`
  - Passed.
- Checked bundle metadata:
  - `CFBundleShortVersionString=0.2.30`
  - `CFBundleVersion=107`
  - `PDTLatestFeatureSlug=laptop-screen-fit`
- `swift test`
  - Not run successfully on this machine because XCTest is unavailable under the active Command Line Tools developer directory.

## Known Gaps Or Follow-Up Items

- Manual visual verification on the target laptop screen is still needed.
- The app may still reopen at a previously saved oversized window frame, but the lowered minimum should allow macOS and the user to resize it within the laptop viewport.

## Shipped Release

- APP_VERSION: `0.2.30`
- APP_BUILD: `107`
- APP_FEATURE_SLUG: `laptop-screen-fit`
