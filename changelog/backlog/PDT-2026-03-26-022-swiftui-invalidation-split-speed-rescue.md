# PDT-2026-03-26-022 SwiftUI Invalidation Split Speed Rescue

- Item ID: `PDT-2026-03-26-022`
- Title: `SwiftUI invalidation split speed rescue`
- Current status: `awaiting_user_review`
- Target release version: `0.1.60`
- Target feature slug: `swiftui-invalidation-split-speed-rescue`

## User Request Summary

The app is still extremely slow in real use. Arrow-key navigation still pauses between items, scrolling is worse, and opening the sidebar can take several seconds. The user asked for a thorough speed-up plan, research into the likely causes, and direct implementation to get performance back to an effectively instant feel.

## Plan Provenance

The invalidation-split approach in this spec is an assistant-proposed implementation plan, not a user-authored plan. It is recorded here because the user approved that approach for execution after reviewing it in chat.

## Constraints

- Keep the current UI design, grouped review, compare layout, and tooltip behavior unless a change is required for speed.
- Do not add animations or transitions.
- Speed and responsiveness outrank further feature polish.
- Keep backlog and changelog aligned with the code during the rescue work.

## Implementation Intent

- Add internal latency instrumentation so navigation, scroll, compare, and sidebar actions can be measured while debugging.
- Split hot UI state out of the monolithic `AppState` into narrower observable slices so focus and selection changes do not invalidate the entire shell.
- Precompute sidebar and session summary snapshots so sidebar open/close does not rebuild review data.
- Rebuild review-facing state as stable snapshots and move scroll bookkeeping to a dedicated navigation slice.
- Keep persistence, thumbnail generation, and archive loading off the critical path for focus-only and sidebar-only interactions.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation on a large session:
  - hold arrow keys inside the visible review page
  - arrow across a page boundary that requires scrolling
  - open and close the sidebar repeatedly
  - switch grouped and flat review
  - open and close compare after multiple triage actions

## Success Criteria

- Focus-only navigation no longer invalidates the sidebar, compare overlay, or inspector shell.
- Sidebar open/close is materially faster because review and compare state do not rebuild with it.
- Review arrow-key movement is immediate while the target item remains in view, with noticeably lower latency even when scrolling is needed.
- The current UI and triage behavior remain intact while the speed path improves.
