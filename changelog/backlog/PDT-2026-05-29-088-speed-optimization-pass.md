# PDT-2026-05-29-088 speed optimization pass

item_id: PDT-2026-05-29-088
title: Review-pipeline speed optimization pass
status: implemented_pending_review
target_release_version: 0.2.43
target_feature_slug: review-refresh-coalescing

## Concurrency Note (read first)

This work was done in an isolated git worktree on branch
`test/speed-optimizations-2026-05-29` while a separate Codex Computer Use agent was
concurrently editing the main checkout (item PDT-2026-05-29-087, "Computer Use
accessibility state", touching ContentInspectorViews / ContentInspectorWorkflowViews /
APP_RELEASE.env). The worktree was branched from the committed `main` (af13c6d) to
avoid clobbering that in-flight work. On merge, reconcile `APP_RELEASE.env` and the
append-only JSONL logs by keeping both agents' entries. The `.app` bundle was
deliberately NOT installed to `/Applications` to avoid colliding with the concurrent
agent's installed build.

## User Request

Review the codebase for speed and feature optimizations, run a detailed analysis,
outline key suggestions, create a test branch, and implement the safe wins. Long
unattended session: implement what is provably behavior-preserving; only *recommend*
anything that would change interaction, layout, selection, shortcuts, navigation,
modals, or workflow (those need explicit approval per DESIGN.md).

## Analysis (Detailed)

The review pipeline is a snapshot/diff architecture. `AppState` (`@MainActor`,
`ObservableObject`) holds all `@Published` state; most setters have `didSet`
observers calling `refresh*State()`. Each `refresh*State()` builds an immutable
snapshot struct and calls `state.update(snapshot)`, which guards with
`guard self.snapshot != snapshot` (an `Equatable` deep-compare) before sending
`objectWillChange`. Views observe the per-domain `*State` objects and read
`state.snapshot`. The grid `ForEach(visibleItems)` iterates `ReviewItemSnapshot`s;
thumbnails are decoupled per-item via `ThumbnailSlot` (`ObservedObject`), so cell
images load/update independently of selection — that part is already good.

### Confirmed hot-path costs (large-session triage)

1. **Double full review rebuild per user action.** `applyReviewSelectionState`
   (choke point for click, arrow, select-all, toggle) sets up to five `@Published`
   properties in sequence. `selectedMediaItemIDs` and `focusedReviewItemID` each fire
   `refreshReviewState` + `refreshInspectorState` + `refreshCompareState`. Net per
   single click: `refreshReviewState` runs **twice** (first result immediately
   superseded), inspector twice, compare twice, navigation twice. Same multi-set
   pattern in `navigatePreview`, `drillIntoFocusedInlineSection`,
   `revealInlineMediaItem`, `selectInlineMediaItem`, `selectFolderNodes`.

2. **`refreshReviewState` is O(N).** Rebuilds every `ReviewItemSnapshot`
   (`visibleMediaItems.map { makeReviewItemSnapshot }`), rebuilds `itemSnapshotsByID`,
   then `ReviewState.update` deep-compares the whole snapshot. With 2× rebuilds, one
   arrow-key in a 1000-photo day ≈ 2000 snapshot allocs + two O(N) dict builds + two
   O(N) deep compares on the main thread.

3. **`groupedReviewSections` rebuilt every review refresh in grouped mode.**
   `refreshReviewState` calls `inlineSectionOrganizer.groupedReviewSections(from:)`
   uncached, even though its input is generation-cached.

4. **`ReviewSnapshot` Equatable compares the derived `itemSnapshotsByID` redundantly**
   (same N snapshots compared twice per guard).

5. **`thumbnailImageCache` (`NSCache<NSURL,NSImage>`) is unbounded** (no countLimit/
   totalCostLimit, unlike `DecodedImagePipeline`'s 96/512MB).

6. **Redundant per-cell thumbnail kick-off.** Grid/list cell `.onAppear` calls
   `requestThumbnail`; `ThumbnailImageSurface.onAppear` *also* calls `requestThumbnail`
   + `thumbnailImage`. `requestThumbnail` runs twice per cell appearance.

## Implementation Intent (behavior-preserving only)

- **OPT-A Refresh coalescing transaction.** Re-entrant `withCoalescedRefreshes`
  wrapper + `pendingRefreshes` OptionSet. Split each `refresh*State()` into a
  dispatcher (enqueue inside a transaction, run immediately otherwise) +
  `performRefresh*State()` body. Wrap multi-`@Published`-set methods. One user action
  ⇒ one refresh per domain; final snapshots identical.
- **OPT-B** Custom `ReviewSnapshot ==` skipping derived `itemSnapshotsByID`.
- **OPT-C** Memoize `groupedReviewSections` in `refreshReviewState` by
  `inlineSectionCacheGeneration`.
- **OPT-D** Bound `thumbnailImageCache` (countLimit + totalCostLimit).
- **OPT-E** Drop redundant `requestThumbnail` from `ThumbnailImageSurface`; keep decode.

## Constraints

- No interaction/layout/selection/shortcut/navigation/modal/workflow change (DESIGN.md).
- Selection outcome byte-identical.
- Coalescing stays synchronous (tests read `reviewState.snapshot` right after calls).
- Tracking + APP_RELEASE.env in lockstep on this branch.

## Test Conditions

- `swift build` + `swift test` pass.
- New regression test: a single `handleGridSelection` advances `ReviewState.generation`
  by exactly 1 (was 2), with identical selection/focus outcome.
- Existing ReviewInteraction / SelectionManager / StateSupport / Thumbnail tests green.

## Success Criteria

- One selection action ⇒ one review-state publish.
- Grouped review stops rebuilding `groupedReviewSections` on selection changes.
- Thumbnail decode cache bounded.
- No UX change; all existing tests preserved.

## Recommendations (NOT implemented — need approval, mostly design-affecting)

- R1 Decouple selection from per-item snapshot (cells read selection from a top-level
  set) so selection needs no `visibleItems` rebuild. Larger refactor.
- R2 Retina-correct thumbnail decode sizing / on-disk cache format. Changes disk cache.
- R3 Off-main snapshot construction for very large days.
- R4 Feature ideas (filmstrip, star ratings, EXIF overlay, keyword/face filters,
  compare zoom-sync) — design changes needing DESIGN.md amendment + approval.

## Current Status

implemented_pending_review on `test/speed-optimizations-2026-05-29`; awaiting user
verification of `APP_VERSION 0.2.43` (rebased onto main; superseded the 0.2.42 version collision with the concurrent item 087).
