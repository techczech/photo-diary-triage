# PDT-2026-05-29-088 speed optimization pass — report

item_id: PDT-2026-05-29-088
shipped_release_version: 0.2.43
shipped_feature_slug: review-refresh-coalescing
status: implemented_pending_review
branch: test/speed-optimizations-2026-05-29 (isolated git worktree)

## Concurrency Note

Implemented in an isolated git worktree branched from committed `main` (af13c6d) while a
separate Codex Computer Use agent was concurrently editing the main checkout
(PDT-2026-05-29-087, "Computer Use accessibility state"). This avoided clobbering that
agent's in-flight, uncommitted source edits and its `/Applications` install. On merge,
reconcile `APP_RELEASE.env` and the append-only JSONL logs by keeping both agents'
entries.

## Summary Of What Changed

Behavior-preserving speed pass on the review pipeline. No interaction/layout/selection/
shortcut/navigation/modal/workflow change (DESIGN.md respected). Five optimizations:

- **OPT-A — Refresh coalescing (headline).** A single user selection action (click,
  arrow, select-all, toggle, navigate-preview, drill-in, reveal) used to set several
  `@Published` properties in sequence, each `didSet` firing a full `refreshReviewState`
  (plus inspector/compare/navigation). One click fired `refreshReviewState` **twice**
  and produced two distinct review-state publishes (an intermediate focus-only snapshot
  immediately superseded by the focus+selection snapshot). Added a re-entrant
  `withCoalescedRefreshes` transaction + a `PendingRefreshKinds` option set. Each
  `refresh*State()` is now a thin dispatcher (enqueue while inside a transaction, run
  immediately otherwise) over a `performRefresh*State()` body; the multi-set methods are
  wrapped so the batch flushes once at the end. One action ⇒ one refresh per domain ⇒ one
  publish. Synchronous, so callers/tests still read up-to-date snapshots immediately.

- **OPT-B — O(1) snapshot index equality.** `ReviewSnapshot.itemSnapshotsByID` is derived
  purely from `visibleItems`, yet the synthesized `Equatable` compared the same N
  item snapshots a second time on every refresh guard. Wrapped it in
  `ReviewItemSnapshotIndex` (subscript preserved) whose `==` is a constant `true`, so the
  owning snapshot's equality is decided by `visibleItems` and the other fields only. No
  field-by-field custom `==` (so no risk of omitting a real field).

- **OPT-C — Memoize `groupedReviewSections`.** `performRefreshReviewState` called
  `inlineSectionOrganizer.groupedReviewSections(from:)` uncached on every refresh while
  grouped review was active. Now memoized by `inlineSectionCacheGeneration` + organization
  mode, matching the existing `organizedInlineSections` caching.

- **OPT-D — Bound the thumbnail decode cache.** `thumbnailImageCache`
  (`NSCache<NSURL,NSImage>`) had no limits; set `countLimit = 512` and
  `totalCostLimit = 256 MB`, and now insert with a pixel-area cost so the cost limit is
  effective. Mirrors the already-bounded `DecodedImagePipeline` cache.

- **OPT-E — Drop redundant per-cell thumbnail request.** The flat grid and flat list
  `ForEach` cells called `requestThumbnail` in `.onAppear` even though the embedded
  `ThumbnailImageSurface` already requests on appear (it must, because the inspector also
  uses it without an outer request). Removed the two redundant outer `.onAppear` calls.

## Files Changed

- `Sources/PhotoDiaryTriage/AppState.swift` — coalescing transaction + dispatchers +
  `perform*` split; wrapped `applyReviewSelectionState`, `navigatePreview`,
  `drillIntoFocusedInlineSection`, `revealInlineMediaItem`, `selectInlineMediaItem`,
  `selectFolderNodes`, `refreshAllUIState`; memoized `groupedReviewSections`; bounded
  `thumbnailImageCache` + insertion cost.
- `Sources/PhotoDiaryTriage/UIState.swift` — `ReviewItemSnapshotIndex` type; `ReviewSnapshot.itemSnapshotsByID` retyped; `.empty` updated.
- `Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift` — removed two redundant
  outer thumbnail-request `.onAppear` blocks.
- `Tests/PhotoDiaryTriageTests/ReviewInteractionTests.swift` — 3 new tests:
  single-grid-selection / selectMediaItems publish exactly once;
  `ReviewItemSnapshotIndex` equality/lookup invariant.
- `APP_RELEASE.env` — 0.2.43 / build 120 / review-refresh-coalescing (rebased onto main; 0.2.42/119 was taken by the concurrent item 087).

## Verification

- `swift build` — **passed** (Build complete, 27.5s). Only warning is a pre-existing
  non-sendable `NSImage?` actor-boundary warning in the unchanged
  `decodeThumbnailIfNeeded` call.
- `git diff --check` — passed (no whitespace errors).
- `swift test` — **could not run on this machine**: Command Line Tools only (Swift 5.10,
  no full Xcode / no alternate toolchain), so SwiftPM aborts at XCTest path discovery
  ("XCTest not available"). This is the same documented toolchain limitation that blocked
  the prior crop work. The new tests are written against existing test patterns/helpers
  and compile by inspection, but must be executed on a machine with a full Swift toolchain.

## Known Gaps / Follow-up

- **Run `swift test`** on a full-toolchain machine to execute the new + existing suites
  (selection, shortcut scope, grid geometry, persistence). Build verification only here.
- **GUI spot-check** the review grid after merge: scroll the flat grid and flat list and
  confirm thumbnails still load on first appearance (OPT-E removed the redundant outer
  request; the embedded surface still requests).
- `.app` bundle was deliberately **not** built/installed to `/Applications` to avoid
  colliding with the concurrent agent's installed build. Build/install from this branch
  after merge.
- Not implemented (need approval; mostly design-affecting): R1 decouple selection from
  per-item snapshot; R2 retina-correct thumbnail decode sizing / cache format; R3 off-main
  snapshot construction; R4 feature ideas (filmstrip, ratings, EXIF overlay, filters,
  compare zoom-sync) — require a DESIGN.md amendment.

## Handoff — please test APP_VERSION 0.2.43

Intended user-visible behavior in 0.2.43 (merged to main):
identical to 0.2.41 in every interaction, but snappier selection/arrow-key triage on
large days (one review refresh per action instead of two, lighter equality checks, no
grouped-section rebuild on selection, bounded thumbnail memory). Please build/install from
this branch and confirm: keyboard arrow navigation, click / shift-click / cmd-click
selection, S/C/X/D/R shortcuts, grid and grouped review, preview/compare, and thumbnail
loading all behave exactly as before — just faster.
