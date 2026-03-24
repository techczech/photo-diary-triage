# Codebase Review: Photo Diary Triage

**Date:** 2026-03-24
**Scope:** Full codebase review (~4,800 lines, 21 Swift files)
**Purpose:** Identify improvements in design, functionality, speed, and development process

---

## 1. DESIGN / ARCHITECTURE

### 1a. AppState God Class (P0)

**File:** `Sources/PhotoDiaryTriage/AppState.swift` — 1,589 lines

This single `@MainActor ObservableObject` class owns:
- 28 `@Published` properties
- ~60 methods
- UI state (selection, focus, expansion, pane tracking)
- Business logic orchestration (scanning, grouping, importing)
- Sidebar tree building
- Archive browsing
- Session lifecycle management
- Volume mount monitoring

**Problem:** Untestable in isolation, high cognitive load, every change risks side effects across unrelated features.

**Recommendation:** Extract into focused sub-objects:
- `SessionManager` — session lifecycle: open, close, save, restore
- `BrowserViewModel` — sidebar tree building, archive inspection, node expansion
- `SelectionManager` — multi-pane selection coordination (sidebar, folder, media)
- `ImportWorkflow` — import planning, execution, verification status
- Keep `AppState` as a thin coordinator composing these via `@Published` sub-objects

### 1b. ContentView Monolith (P1)

**File:** `Sources/PhotoDiaryTriage/ContentView.swift` — 1,452 lines

Contains the entire UI: sidebar, detail panes, inline grids, inspector panel, modals, sheets, toolbar, keyboard handlers.

**Recommendation:** Extract into SwiftUI sub-views:
- `SidebarView` — navigation tree
- `MediaGridView` — photo grid with selection
- `InspectorPanelView` — right-hand details panel
- `WalkMetadataForm` — walk title/location/notes editing
- `ImportProgressSheet` — import workflow UI

### 1c. No Dependency Injection / Protocols

Services are concrete classes instantiated directly in `AppState.init()`. `FileManager.default` is used directly throughout.

**Recommendation:** Define protocols (`FileScanning`, `SessionPersisting`, `MetadataExtracting`, etc.) to enable:
- Unit testing with mocks/stubs
- Swapping implementations (e.g., in-memory session store for tests)
- Cleaner separation of concerns

This is a prerequisite for meaningful test expansion and should be addressed as part of the AppState decomposition.

### 1d. Missing Error Boundary at Init (P0)

```swift
// AppState.swift:53-54
self.sessionStore = try! SessionStore(...)  // crashes on DB failure
self.previewStore = try! PreviewStore(...)  // crashes on cache failure
```

**Problem:** If the SQLite database or preview cache directory can't be created (permissions, disk full, corrupted DB), the app crashes at launch with no recovery.

**Recommendation:** Use `do/catch` with graceful degradation — e.g., in-memory fallback, or present a user-facing error alert with a "Reset" option.

---

## 2. FUNCTIONALITY

### 2a. Silent Failures Throughout (P1)

- `PreviewStore.generateThumbnail()` returns `Bool` but errors are swallowed
- `MetadataExtractor` returns empty metadata on failure without logging
- `try?` used in places that should at least log what went wrong

**Recommendation:** Add a lightweight logging layer using `os_log` / `Logger`. Critical for debugging photo-handling edge cases: corrupt files, unsupported RAW variants, permission issues on external volumes.

### 2b. No Lifecycle State Transition Validation (P2)

`LifecycleState` enum defines states (discovered → imported → verified → sourceCleanupPending → sourceCleaned) but nothing enforces valid transitions. A media item could jump from `discovered` to `sourceCleaned` programmatically.

**Recommendation:** Add a `canTransition(to:)` method on `LifecycleState` that enforces the directed graph of valid transitions. Reject invalid transitions with a descriptive error.

### 2c. Slugifier Edge Case

The slug function could produce empty or degenerate slugs for non-ASCII input (e.g., CJK characters → all hyphens → collapsed to empty). The fallback to "photo-walk" exists but could cause collisions across multiple sessions on the same day.

**Recommendation:** Add a transliteration step (`CFStringTransform`) before slugifying, and append a short hash suffix when the slug degenerates to the fallback.

### 2d. Import Verification Is Size-Only (P3)

`ImportCoordinator` verifies imports by comparing file sizes. This misses corruption where size is preserved but content differs.

**Recommendation:** Add optional checksum verification (SHA-256) as a setting. Fast mode = size only (default), thorough mode = checksum.

### 2e. No Progress Reporting During Import (P2)

Large imports show no incremental progress. The status message updates only at completion.

**Recommendation:** Publish per-file progress via `@Published var importProgress: (current: Int, total: Int)?` so the UI can show "Importing 12/47...".

### 2f. DateFormatter Thread Safety

`DateFormatting.walkFolderFormatter` is a `static lazy var DateFormatter`. `DateFormatter` is not thread-safe by default.

**Recommendation:** Use `ISO8601DateFormatter` where possible (thread-safe), or wrap access in a serial queue. Minor risk today but becomes real with concurrent imports.

---

## 3. SPEED / PERFORMANCE

### 3a. Sequential File Import (P1)

`ImportCoordinator` copies files one at a time. On SSDs with good parallel read performance, this leaves throughput on the table.

**Recommendation:** Use `TaskGroup` for concurrent file copies with a configurable concurrency limit (4-8 parallel copies). Could cut import time significantly for large sessions.

### 3b. No Pagination for Large Sessions

All `MediaItem`s are loaded into memory at once. A session with 2,000+ photos will increase memory pressure and slow grid rendering.

**Recommendation:** Consider lazy data loading or windowed pagination. SwiftUI `LazyVGrid` helps with view recycling but the underlying data should also support windowing for very large sessions.

### 3c. Archive Tree Rebuilt on Every Navigation (P3)

`ArchiveLibraryInspector.existingYearFolders()` and archive node builders run on every sidebar selection change, hitting the filesystem each time.

**Recommendation:** Cache the archive tree and invalidate only after imports complete or on manual refresh.

### 3d. Sequential Thumbnail Generation (P2)

Thumbnails are generated one at a time via `QLThumbnailGenerator`. For sessions with hundreds of photos, this creates visible lag.

**Recommendation:** Use concurrent thumbnail generation with `TaskGroup`, prioritizing visible (viewport) items first.

### 3e. No Precomputed Sidebar Counts (P3)

Sidebar nodes likely recount children on every SwiftUI render cycle.

**Recommendation:** Compute and cache item counts when the session loads or grouping changes, not on every view update.

---

## 4. DEV PROCESS

### 4a. Testing Is Minimal (P0)

**File:** `Tests/PhotoDiaryTriageTests/PhotoDiaryTriageTests.swift` — 7 tests, 195 lines

Only the service layer is tested (GroupingService, ArchivePlanner, ManifestRenderer, slug). Missing:
- **SessionStore tests** — SQLite operations, migration, upsert, recovery
- **Selection logic tests** — multi-select, shift-click, keyboard navigation
- **Lifecycle transition tests** — valid/invalid state changes
- **Import workflow tests** — file copy, verification, error handling
- **Keyboard shortcut scope tests** — DESIGN.md explicitly mandates these

The test bootstrap task (PDT-2026-03-24-001) is currently **blocked**.

**Recommendation:** Prioritize unblocking the test bootstrap. Then expand in this order:
1. SessionStore (persistence correctness is critical)
2. Lifecycle state transitions
3. Selection logic (extract from AppState first)
4. Import workflow (with mock FileManager)

### 4b. No CI/CD Pipeline (P2)

All builds and tests are run manually. No GitHub Actions, no automated checks.

**Recommendation:** Add a minimal GitHub Actions workflow:
1. `swift test` on every push
2. `swift build --configuration release` to catch compile errors
3. Optionally verify app bundle creation via the build script

### 4c. .gitignore Missing Key Entries (P1)

`.tmp-home/` (12MB compiler cache) and `dist/` (compiled app bundle) are untracked but not gitignored. They pollute `git status`.

**Recommendation:** Add to `.gitignore`:
```
.tmp-home/
dist/
```

### 4d. No Linting or Formatting (P3)

No SwiftLint, SwiftFormat, or code style enforcement.

**Recommendation:** Add SwiftLint with a minimal config. Default rules catch force unwraps, long lines, and overly large files. Can run as a pre-commit hook or CI step.

### 4e. Hardcoded User-Specific Defaults

`AppSettings.default()` contains paths specific to the developer's machine (`/Volumes/EOS_DIGITAL/`, OneDrive paths).

**Recommendation:** Use `FileManager.default.urls(for:in:)` for the archive default and detect mounted volumes dynamically for the source default.

### 4f. Version Management Could Be Automated (P3)

`APP_RELEASE.env` is manually edited. The build script sources it, and `AppRelease.swift` reads it.

**Recommendation:** Add a `scripts/bump_version.sh` that increments the build number (and optionally the version), then commits. Reduces manual steps and prevents build number drift.

### 4g. Changelog/Backlog System Overhead

The JSONL + markdown spec + agent governance system is thorough (16 backlog items, 15 reports) but heavy for a single-developer project.

**Observation:** This is a judgment call. The system provides good audit trail but the overhead may not justify itself unless the project grows contributors. Worth periodically evaluating whether git log + GitHub Issues would suffice.

---

## Summary: Prioritized Recommendations

| Priority | Area | Item | Backlog ID |
|----------|------|------|------------|
| P0 | Design | Break AppState into focused sub-objects | PDT-2026-03-24-002 |
| P0 | Design | Fix try! crash points with graceful error handling | PDT-2026-03-24-003 |
| P0 | Dev Process | Expand test coverage beyond service layer | PDT-2026-03-24-004 |
| P1 | Design | Extract ContentView into sub-views | PDT-2026-03-24-005 |
| P1 | Functionality | Add logging for silent failures | PDT-2026-03-24-006 |
| P1 | Speed | Concurrent file imports via TaskGroup | PDT-2026-03-24-007 |
| P1 | Dev Process | Add .tmp-home/ and dist/ to .gitignore | PDT-2026-03-24-008 |
| P2 | Functionality | Enforce valid lifecycle state transitions | PDT-2026-03-24-009 |
| P2 | Functionality | Show per-file progress during imports | PDT-2026-03-24-010 |
| P2 | Speed | Parallel thumbnail generation | PDT-2026-03-24-011 |
| P2 | Dev Process | Add GitHub Actions CI pipeline | PDT-2026-03-24-012 |
| P3 | Speed | Cache archive tree, precompute sidebar counts | PDT-2026-03-24-013 |
| P3 | Dev Process | Add SwiftLint and version bump script | PDT-2026-03-24-014 |
| P3 | Functionality | Optional SHA-256 verification for imports | PDT-2026-03-24-015 |
