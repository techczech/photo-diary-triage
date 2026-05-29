# PDT-2026-05-28-085 crop interaction repair

item_id: PDT-2026-05-28-085
title: Crop interaction repair
status: awaiting_user_review
target_release_version: 0.2.41
target_feature_slug: crop-interaction-repair

## User Request

Repair the crop interaction properly after the previous implementation broke core behavior:

- Double-clicking a grid item must open preview again.
- Drag Crop must not save immediately on mouse-up.
- Drag Crop must allow adjustment before saving.
- The design must be based on real crop-tool behavior, not assumptions.
- Computer Use should be used for live verification if the user confirms broad permission for this repair session.
- Local build work should clean stale disk-heavy artifacts periodically so old builds do not consume the disk.
- Crop writing must clean any temporary files and prevent crop outputs from ballooning in size.

## Research Notes

- Apple Photos crop flow: double-click photo, enter edit, choose Crop, drag selection rectangle, then explicitly click Done to save or Revert to Original to cancel.
- Apple Preview crop flow: select the area to keep, then click Crop; selection and commit are separate steps.
- Apple AppKit event handling: mouse click and key/trackpad events are delivered to the relevant responder/view; custom bridges must not steal events from controls.
- Apple cursor-rect guidance: cursor rects belong in `resetCursorRects`, with invalidation when the interactive region changes.

## Constraints

- Keep normal grid click, shift-click, command-click, and double-click behavior.
- Do not reintroduce a grid overlay that swallows crop/original link buttons or triage buttons.
- Keep existing crop geometry mapping.
- Preserve keyboard crop visible command.
- Keep AppKit bridge narrow; SwiftUI remains source of truth for confirmation state.
- Do not use Computer Use actions until the user confirms broad permission.
- Disk cleanup must be conservative: remove local generated build artifacts only, not user photos, app runtime data, source files, or durable changelog/backlog records.
- Crop-service cleanup must not remove original photos or committed crop outputs; only temporary/intermediate files are disposable.

## Implementation Intent

- Restore grid double-click by making the review-card click target cover the non-control card body while leaving buttons clickable.
- Change manual drag crop into a two-step flow:
  - drag creates or updates a pending crop rectangle;
  - crop is saved only after an explicit Apply/Save Crop command;
  - Cancel/Escape clears the pending rectangle without saving.
- Add adjustment affordances:
  - drag inside existing selection moves it;
  - drag handles/edges resizes it;
  - show handle/boundary cursor feedback.
- Keep crop selection visible after mouse-up.
- Surface clear status messages for crop selection created, adjusted, applied, or cancelled.

## Test Conditions

- Review interaction test proving double-click opens preview.
- Unit-level crop selection model tests for create, move, resize, clamp, cancel/apply readiness.
- Build with `swift build`.
- If local test runner still lacks XCTest, record the exact blocker.
- After permission: install/launch app and use Computer Use for grid double-click and crop-selection flow verification.
- Disk-space check before and after build/install; clean safe stale artifacts such as `.build` intermediates or old `dist` bundles when needed.
- Crop-service tests for temporary-file cleanup and bounded crop output size.

## Success Criteria

- Double-clicking a grid card opens preview.
- Dragging a crop rectangle does not create a crop file immediately.
- User can adjust the pending crop before applying.
- Apply creates a crop and switches to the cropped version.
- Cancel/Escape exits or clears crop mode without creating duplicate crops.
- Buttons inside cards remain clickable.
- Build/install work does not leave unnecessary stale build artifacts consuming disk space.
- Crop attempts do not leave temporary files behind.
- Crop output encoding stays bounded and does not create unexpectedly large cropped files.

## Implementation Notes

- Restored grid double-click by moving the AppKit click target onto non-control card regions: thumbnail and metadata row.
- Reworked Drag Crop into a pending-selection flow:
  - drag creates or updates a visible selection rectangle;
  - mouse-up does not write a crop;
  - Save Crop explicitly writes the pending crop;
  - Cancel/Escape clears the pending crop.
- Added crop selection handles and move/resize geometry.
- Kept pending crop selections normalized across zoom/layout changes before reprojecting them to the displayed document rect.
- Invalidated cursor rects when crop selections appear, change, or clear so handle/move cursors can update.
- Wrote crop outputs through temporary files, removed temp files on all exits, and removed completed crop outputs if manifest writing fails.
- Changed unknown crop output formats from TIFF fallback to bounded JPEG fallback; JPEG/HEIC crops use lossy compression.
- Built and installed `/Applications/PhotoDiaryTriage.app` as `APP_VERSION=0.2.41`, `APP_BUILD=118`, `APP_FEATURE_SLUG=crop-interaction-repair`.

## Verification

- `swift build` passed.
- `swift test` blocked before test compilation because local Command Line Tools cannot provide XCTest platform paths; error remains `XCTest not available`.
- `git diff --check` passed.
- `./scripts/build_app_bundle.sh` passed.
- Installed bundle metadata:
  - `CFBundleShortVersionString=0.2.41`
  - `CFBundleVersion=118`
  - `PDTLatestFeatureSlug=crop-interaction-repair`
- `codesign --verify --deep --strict --verbose=2 /Applications/PhotoDiaryTriage.app` passed.
- Running process path: `/Applications/PhotoDiaryTriage.app/Contents/MacOS/PhotoDiaryTriage`.
- System Events saw one `Photo Diary Triage` window and reported `PhotoDiaryTriage` frontmost.
- Computer Use `list_apps` reported `PhotoDiaryTriage` frontmost and running from `/Applications/PhotoDiaryTriage.app`.
- Disk headroom after build/install was about `16 GiB` free on `/System/Volumes/Data`.

## User Review Focus

- In `APP_VERSION=0.2.41`, double-click a grid thumbnail or metadata row and confirm preview opens.
- In preview or compare, enable Drag Crop, drag a rectangle, release, and confirm no crop file appears until Save Crop.
- Move and resize the pending rectangle before saving.
- Press Escape or Cancel and confirm no duplicate crop is created.
- Save the crop and confirm the app switches to the cropped version with the original/crop links still usable.
