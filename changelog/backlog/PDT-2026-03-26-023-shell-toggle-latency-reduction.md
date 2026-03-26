# PDT-2026-03-26-023 Shell Toggle Latency Reduction

- Item ID: `PDT-2026-03-26-023`
- Title: `Shell toggle latency reduction`
- Current status: `approved_for_implementation`
- Target release version: `0.1.61`
- Target feature slug: `shell-toggle-latency-reduction`

## User Request Summary

After testing `0.1.60`, the user reported that sidebar and inspector toggles are still too slow. Arrow-key review movement is better than before, but it should still be faster.

## Constraints

- Preserve the current UI design and keyboard behavior.
- Do not add animations or transitions.
- Keep the speed-first priority over further feature polish.

## Implementation Intent

- Remove the remaining expensive shell toggle path for the left sidebar by keeping the sidebar view alive and toggling app-managed visibility instead of relying on the system split-view sidebar controller.
- Tighten the inspector shell toggle path so the hidden inspector keeps its container state without forcing heavy content work on every show/hide transition.
- Reduce review arrow latency further by avoiding shell-level layout work when only focus changes.

## Test Conditions

- `swift build`
- `swift test`
- `./scripts/build_app_bundle.sh`
- Manual validation:
  - repeated sidebar open/close
  - repeated inspector open/close
  - repeated arrow-key movement in visible review items
  - arrow-key movement when a scroll boundary is crossed

## Success Criteria

- Sidebar open/close is materially faster and no longer feels like a multi-second action.
- Inspector open/close is materially faster and no longer blocks interaction.
- Arrow-key moves remain correct and feel faster than `0.1.60`.
