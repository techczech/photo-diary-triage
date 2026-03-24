# PDT-2026-03-23-007 Inline Sections Entrypoint Fix Report

## Summary Of What Changed

- Fixed the main launch-path bug that prevented the `0.1.3` inline day-sections UI from appearing in normal use.
- Restored sessions now select the preferred inline-capable node instead of always landing on `session-root`.
- Same-folder SSD auto-load now repositions the UI to the preferred inline-capable node instead of leaving the user on the old entry point.
- Tracking cleanup corrected this report after it was originally recorded with the wrong shipped release metadata.

## Files Changed

- `APP_RELEASE.env`
- `Sources/PhotoDiaryTriage/AppState.swift`

## Verification Performed

- `swift build`
- rebuilt the packaged app bundle
- verified the packaged app launches successfully
- verified the shipped bundle metadata reflects the new release and feature slug

## Known Gaps Or Follow-Up Items

- This hotfix still needs user review in the running app to confirm the inline controls are now visible in the normal workflow.

## Shipped Release

- Version: `0.1.5`
- Feature slug: `inline-sections-entrypoint-fix`
