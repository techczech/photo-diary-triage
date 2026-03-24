# Photo Walk Triage & Diary — Dictated Idea Scope

> Transcribed from WhatsApp voice memo, 2026-03-21 08:20. Raw transcription by Parakeet v3, cleaned up for readability.

## Core Concept

An extremely lightweight SwiftUI Mac app for photo walk triage and diary management. When returning from a photo walk, copy all files into a folder, and the app handles organization, cataloging, and triage.

## Key Features

### 1. Photo Import & Thumbnail Preview

- Load lightweight thumbnails from a folder of photos (may need FFmpeg or similar for fast preview generation)
- Support zoom-in for closer inspection
- Need to decide on the best approach for fast thumbnail rendering

### 2. Triage Workflow

- Quickly select photos to **delete** (duplicates, bad shots)
- Photos to **keep** get organized into subfolders
- Folder structure: `Year / Month / Day` — but with an added level where days are annotated with:
  - What the photo walk was
  - Where it was (location)
  - Notes
  - Description of key images and locations

### 3. Burst & Group Detection

- **Burst grouping:** Photos taken within seconds of each other (same burst) — extract from EXIF if possible. Usually want to pick just one or two from each burst for triage.
- **Proximity grouping:** Photos taken within a configurable interval (e.g., 5 or 10 minutes) — likely related shots from the same spot. Can assign a shared map reference to the whole group.
- Two organizational levels: tight (burst) and loose (time proximity)

### 4. Metadata & Manifests

- First step: process all photos, extract all EXIF metadata, analyze timestamps
- Store in a lightweight database (SQLite) for app speed
- **But critically:** generate text-based manifests (Markdown) so no important data is trapped in a database
- Per-folder overview manifest (Markdown) with overview of all files
- Per-file manifest (Markdown with YAML frontmatter) containing:
  - All EXIF metadata
  - Which folder it belongs to
  - Which photo walk it belongs to
  - Any additional details
- Also consider a JSONL log file for structured data

### 5. Historical Folder Processing

- Apply the same organization to historical photo folders
- Reorganize, rename, better describe existing collections
- Diary of all photo walks taken over the last 20 years with different cameras
- Eventually fold in phone photos as well

## Integrations

### A. LM Studio (Local LLM)

- Connect to a local LM Studio server
- Use a local model to **describe pictures** (image captioning)
- Use those descriptions to **write up an overview** of what each folder/walk is about

### B. Google Maps

- Pick areas/locations for each photo or each photo walk
- Know where each walk took place
- Assign map references to groups of photos at once

### C. Strava / Garmin GPX

- Often have a Garmin watch running during walks, synced to Strava
- Import GPX tracks to get better positioning data
- Show routes on maps
- Synchronize GPX timestamps with photo timestamps for location correlation

## Future Considerations (Lower Priority)

- Very lightweight **cropping** functionality — only if good libraries exist and it's easy
- Basic **contrast/adjustment** tools — same caveat
- The most important thing is the **catalog and triage** first

## Suggested First Step

The app should start by:
1. Processing all photos in a folder
2. Extracting all EXIF metadata
3. Analyzing timestamps for burst/proximity grouping
4. Storing results in SQLite for fast access
5. Generating text manifests once triage is complete
