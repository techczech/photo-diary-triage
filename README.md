# Photo Diary Triage

Photo Diary Triage is a local-first macOS app for quickly reviewing photos on an external SSD, deciding what to keep, importing only the chosen images into a structured archive, and preserving enough context to understand the walk later.

This project exists for a simple workflow problem: importing everything is wasteful, deleting during review is risky, and ad hoc notes disappear. The app keeps the source SSD untouched during triage, lets you work fast in a grid-first review UI, and only enables cleanup after import verification and backup confirmation.

## What v0.2.0 Is

`v0.2.0` is the first public milestone release. It is the point where the project became useful enough to create and manage one meaningful record quickly, with a stable enough workflow to share publicly before adding more features.

The current record model is a `Photo Log`: a resumable, named set of photos with notes, scope metadata, and exclusive ownership of its member photos inside the active source workflow.

## Current Functionality

- Scan a source folder directly from an SSD, with `DCIM` resolution when appropriate.
- Review photos in a grid-first interface designed for fast triage.
- Use keyboard and UI controls for common review actions.
- Mark photos as included, candidate, excluded, or undecided.
- Group photos into bursts and looser time clusters for faster browsing.
- Open compare mode for side-by-side inspection.
- Create `Photo Logs` from the current explicit scope with count previews and collision checks.
- Reopen, edit, reveal, and delete active photo logs from the sidebar.
- Show when photos are hidden from the inbox because they already belong to a photo log.
- Copy selected files into a structured archive layout.
- Write durable manifests and JSONL logs for imported sessions.
- Require backup confirmation before source cleanup becomes available.
- Persist sessions and recover from relaunches.
- Skip corrupted stored session rows instead of failing the whole session load.

## Core Workflow

1. Choose a source folder on the SSD.
2. Let the app scan supported media and build groupings.
3. Review the grid, bursts, clusters, and compare views.
4. Mark photos for import or leave them out.
5. Create a `Photo Log` when you want a named, resumable working set.
6. Add title, location, notes, and scope metadata.
7. Import selected photos into the archive.
8. Verify the archive copy and manifests.
9. Confirm backup safety.
10. Clean imported source files only after that explicit confirmation.

## Product Direction

The app is intentionally local-only for now. It is optimized for speed, safety, and durable records rather than cloud sync, editing, or collaboration.

The next phase starts from this milestone: the workflow is now public and usable enough that further feature work can build on a stable baseline instead of on throwaway prototypes.

## Repo Contents

- `Sources/PhotoDiaryTriage/`: macOS app source.
- `Tests/PhotoDiaryTriageTests/`: regression and workflow tests.
- `changelog/backlog/`: request specs.
- `changelog/changelog/`: implementation reports.
- `DESIGN.md`: UX and product rules.
- `PRD.md`: product goals and workflow scope.

## Development

Requirements:

- macOS 14+
- Swift 5.10 toolchain / Xcode with macOS development support

Run locally:

```bash
swift run PhotoDiaryTriage
```

Run tests:

```bash
swift test
```

## Status

This is an active early-stage project. The repo is public because the baseline workflow is now coherent and demonstrable, not because the feature set is finished.

## License

MIT. See [LICENSE](LICENSE).
