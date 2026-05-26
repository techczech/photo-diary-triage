# PDT-2026-05-26-075: Fresh app bundle build

## User request summary

- User reports crop controls are absent in installed app.
- Drag crop also does not work.

## Constraints

- Installed app must run the actual latest compiled executable, not just latest bundle metadata.
- Preserve crop feature behavior from `0.2.31` and `0.2.32`.
- Keep `/Applications/PhotoDiaryTriage.app` install flow reliable.

## Implementation intent

- Fix bundle script so it runs `swift build` before copying executable into `dist/`.
- Rebuild and reinstall the app from a fresh executable.
- Verify installed executable contains crop UI strings and bundle metadata.

## Test conditions

- `swift build` passes.
- `./scripts/build_app_bundle.sh` builds from fresh source.
- `/Applications/PhotoDiaryTriage.app` metadata matches release.
- Installed executable contains crop UI labels.
- Running process comes from `/Applications/PhotoDiaryTriage.app`.

## Success criteria

- Installed app exposes crop controls from the crop releases.
- Packaging script cannot silently ship a stale executable again.

## Current status

- implemented pending user review

## Target release version

- `0.2.33`

## Target feature slug

- `fresh-app-bundle-build`
