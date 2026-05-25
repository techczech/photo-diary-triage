# PDT-2026-05-25-073 quick non-destructive crop

item_id: PDT-2026-05-25-073
title: Quick non-destructive crop
status: approved_for_implementation
target_release_version: 0.2.31
target_feature_slug: quick-nondestructive-crop

## User Request

Add a quick crop feature for triage and archive review.

User needs:

- non-destructive crop output
- copy saved beside original source/archive file
- filename keeps original stem plus `-cropped`
- multiple crops allowed
- manifest describing each crop
- high-quality output
- crop from current zoom/viewport
- manual drag crop
- works in source triage and archive review
- UX thought through; quick, lightweight, low interruption
- release and push to GitHub for MacBook Air use

## Research Notes

Apple API direction:

- `CGImage.cropping(to:)`: rectangular bitmap crop from an existing image.
- `CIImage.cropped(to:)`: good if the pipeline is already Core Image.
- Image I/O `CGImageSource` / `CGImageDestination`: read/write common image formats, preserve metadata, set output quality, finalize file writes.
- `UTType.heic`, `UTType.jpeg`, `UTType.png`, `UTType.tiff`: explicit output type identifiers.

Implementation choice:

- use Image I/O to decode a full-size, orientation-applied source image
- use normalized viewport/manual crop rect from UI, then convert to full pixel crop rect
- use `CGImage.cropping(to:)` for the actual crop
- use `CGImageDestination` with high lossy quality for JPEG/HEIC and lossless PNG/TIFF where relevant
- for RAW/unsupported writable crop outputs, render a high-quality TIFF copy rather than pretending to produce a RAW crop

## UX Plan

User mental model:

- while inspecting a photo, the current zoomed view is already the intended crop candidate
- crop should be one click from that state
- manual crop should be a temporary mode, visible, and end after the drag saves
- original must stay untouched

Preview sheet:

- add `Crop Visible` near zoom controls
- add `Drag Crop` toggle near `Crop Visible`
- shortcut: `V` crops the visible zoomed area
- dragging while `Drag Crop` is enabled saves the dragged crop and exits drag mode
- status message names saved filename and manifest

Compare sheet:

- add crop controls to each compare card
- `Crop Visible` saves the visible part of that card
- global drag-crop mode lets user drag over any compare image
- focused compare item can still use `V`

File behavior:

- first crop: `IMG_0001-cropped.jpg`
- later crops: `IMG_0001-cropped-2.jpg`, `IMG_0001-cropped-3.jpg`
- manifest: `IMG_0001.crops.json`
- manifest appends entries with source path, output path, trigger, normalized rect, pixel rect, source pixel size, output pixel size, app version/build/feature slug, created timestamp

## Issue Split

### Issue 1: Crop engine and manifest

- create crop service
- choose output type from source extension
- create unique crop filename
- decode orientation-applied full image
- crop from normalized rect
- write high-quality output
- append manifest
- test filename collision and manifest append

### Issue 2: Preview crop UX

- track visible viewport rect in zoom canvas
- add crop visible action
- add manual drag crop mode
- wire `V` shortcut
- keep preview navigation and triage shortcuts intact

### Issue 3: Compare crop UX

- track visible rect per compare card
- add per-card crop visible action
- support drag crop on compare cards
- ensure compare selection/triage shortcuts stay scoped

### Issue 4: Release and handoff

- bump `APP_RELEASE.env` to `0.2.31`
- run focused and full tests
- build `dist/PhotoDiaryTriage.app`
- create changelog report and JSONL updates
- commit, push, GitHub release

## Constraints

- no destructive edit of original files
- no source cleanup interaction
- crop writes must stay beside source/archive item
- no broad refactor of preview/compare
- fast UI response; heavy decode/write off main actor
- maintain keyboard-first triage behavior
- archive and camera triage both supported
- RAW crop output is rendered copy, not RAW mutation

## Test Conditions

- service crops a generated image and writes expected dimensions
- repeated crop creates numbered filenames
- manifest is valid JSON and appends multiple entries
- preview visible crop action compiles and remains keyboard reachable
- compare crop controls compile and do not alter selection scope
- full `swift test`
- app bundle build

## Success Criteria

- user can zoom, press crop, and get a cropped copy beside original
- user can enable drag crop, draw a rectangle, and get a cropped copy
- multiple crops from one original do not overwrite each other
- manifest exists beside original and records each crop
- feature works from source triage preview and archive preview/compare
- release is available on GitHub
