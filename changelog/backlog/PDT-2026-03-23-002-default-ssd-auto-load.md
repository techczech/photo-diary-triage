# PDT-2026-03-23-002 Default SSD Auto-Load

## Status

- Current status: `awaiting_user_review`
- Target release version: `0.1.2`
- Target feature slug: `default-ssd-autoload`

## User Request

When the configured default SSD is plugged in, the app should not sit idle and require manual folder selection. The missing behavior is automatic loading or immediate readiness from the default SSD path.

## Constraints

- The configured `defaultSourceRoot` remains the source of truth.
- The behavior must work for the packaged `.app`, not only for developer runs.
- The app must not silently load the wrong folder if the configured SSD root is unavailable or ambiguous.
- The version marker in the UI must advance when this ships.

## Implementation Intent

- Detect whether the configured default SSD root is available on launch.
- If available, automatically load the default source folder or the most likely walk root under it.
- Detect when the volume appears while the app is already open and trigger the same auto-load behavior.
- Keep the behavior safe and explicit in status messaging so the user can tell what was auto-loaded.

## Test Conditions

- App launch with SSD mounted auto-loads from the configured default SSD path.
- App launch with SSD absent does not crash and gives clear status.
- Plugging in the SSD while the app is open causes the app to detect it and auto-load.
- Auto-load does not override an already active manual review session unexpectedly.
- The shipped build shows a new version and feature slug after implementation.

## Success Criteria

- With the SSD mounted, the app is ready to review without needing `Choose SSD Source Folder`.
- With the SSD unplugged, the app remains stable and clearly indicates waiting state.
- Hot-plugging the SSD while the app is open leads to automatic session loading.
