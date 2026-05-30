# PDT-2026-05-26-075 Original Intent Archive Intelligence Review

## Item ID

PDT-2026-05-26-075

## Title

Original intent archive intelligence review

## User Request Summary

Review original intent and feature specs for Photo Diary Triage. Identify what remains unimplemented, especially archive survey with local image-description models, richer geolocation, and manual or assisted map/location assignment for folders, walks, or triage sessions.

## Constraints

- No implementation in this review pass.
- Use repo docs, backlog specs, changelog reports, and source evidence.
- Keep findings aligned with local-first, SSD-first, grid-first workflow.
- Do not propose cloud-first or destructive workflows.
- Preserve design-governance rule: design-affecting changes need explicit approval before implementation.

## Implementation Intent

Produce a status review and phased plan that separates:

- already implemented baseline workflow
- partially implemented location/photo-log metadata
- unimplemented local model description/indexing
- unimplemented map/geolocation assignment
- other original-intent gaps discovered in the specs

## Test Conditions

- Tracking files remain valid JSONL.
- Review references concrete repo evidence.
- Any later implementation must get its own spec, version bump, tests, and changelog report.

## Success Criteria

- User can see what original intent exists in the repo.
- User can see what is done, partial, missing, or deferred.
- User gets a proposed implementation order with risk boundaries.
- No feature is presented as shipped unless code/changelog evidence supports it.

## Research Findings

Evidence reviewed:

- `planning/dictated-idea-scope.md`
- `PRD.md`
- `README.md`
- `DESIGN.md`
- current source model and manifest code
- backlog/changelog entries through `PDT-2026-05-25-074`

Implemented baseline:

- SSD/source folder scanning
- grid-first triage
- include/candidate/exclude/undecided states
- burst and time-cluster browsing
- compare/preview/zoom decision surfaces
- photo-log creation, editing, ownership, and main workspace tab
- manual title/location/notes metadata
- archive copy with manifests and JSONL session log
- archive filesystem naming
- read-only source/archive copy survey using existing per-photo manifests
- archive browsing speed work
- manual app backup export/import
- OneDrive-relative photo-log sync/export for travel workflow
- quick non-destructive crop support

Partially implemented:

- geolocation: EXIF latitude/longitude fields exist and are written to file manifests when present, but there is no map assignment, no place model, and GPS hemisphere/ref handling needs review.
- archive survey: current survey detects whether source items already have archive manifest matches; it does not describe images or summarize folders/walks.
- location assignment: photo logs have one free-text location field; there is no assign-place-to-folder, assign-place-to-time-cluster, assign-place-to-selection, or place-library workflow.
- map/provider architecture: stubs exist for captioning, track correlation, and map references, but they are not wired into app state, UI, manifests, or settings.

Not implemented:

- LM Studio/local-model captioning for individual images.
- local-model folder/walk overview generation.
- semantic archive index/search over captions, notes, places, and manifests.
- GPX/Garmin/Strava import and timestamp correlation.
- map assignment and route visualization.
- historical archive batch tooling beyond repeating one-folder workflows.
- stronger copy verification/checksum mode.
- stronger backup-provider verification.

## Proposed Implementation Plan

Phase 1: metadata foundation.

- Add durable models for place/location assignments, caption records, map references, route references, and archive survey status.
- Keep records local-first and export them to Markdown/YAML plus JSONL.
- Decide scope rules: photo, selection, time cluster, folder, photo log, archive walk.

Phase 2: manual location/place assignment.

- Add a visible `Places` or `Location` workflow in the inspector/photo-log surface.
- Let user assign a typed place to selected photos, a time cluster, a folder, or the current photo log.
- Persist assignments before adding any map or model dependency.

Phase 3: local image description.

- Add settings for a local caption provider, probably LM Studio-compatible localhost endpoint first.
- Run captioning as an explicit, cancellable background job.
- Store per-photo captions and generate draft folder/walk summaries.
- Never overwrite user notes without review.

Phase 4: map and route layer.

- Add GPX import and timestamp-offset calibration.
- Correlate photo timestamps to track points.
- Show route and manual pins after the assignment model exists.
- Keep map assignment editable and reversible.

Phase 5: historical archive survey.

- Scan existing archive folders and manifests in read-only mode first.
- Fill missing manifests/captions/places without moving files.
- Add migration/rename tools only after survey confidence is high.

Phase 6: safety hardening.

- Add optional checksum verification for imported primary and companion files.
- Add richer backup verification only after the local archive identity and OneDrive sync semantics are stable.

## Current Status

research_completed

## Target Release Version

None for review-only pass.

## Target Feature Slug

original-intent-archive-intelligence-review
