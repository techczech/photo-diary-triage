---
item_id: PDT-2026-10-02-112
title: Command layer and owned navigation development checkpoint
status: implementation_in_progress
target_release_version: 0.7.16
target_build: 152
target_feature_slug: command-layer-and-sidebar
installed_release_version: 0.7.15
installed_build: 151
---

# Development checkpoint

Implemented registered commands, effective persisted overrides and generated hints;
owned palette/context/help/capture panels; form/editor/queue commands; actual native
responder routing; owned sidebar/card navigation; view Find. Fixed startup, exact
modifier, native editing/IME, stale selection/context, window/panel lifetime and
cross-window focus/triage defects. Settings persistence errors remain visible.

Files: AppCommandRegistry, CommandKeyboardRouting, CommandPaletteView,
ArchiveSidebarNavigation, ReviewCommandInputView; AppCommands/AppState/Models/UIState;
Content/Archive/Settings/Google/description/review views; three command test files;
APP_RELEASE.env and matching tracking. No new dependency.

Full verification: 505 tests / 2 suites, 30.799 s, 58 new command functions. Native
hidden windows, real NSTextView/NSTextField editor and NSWindow event paths. Distinct
pre-fix logs plus deliberate sheet/IME guard reversal prove the defects are detected.
Final run: `/private/tmp/walkfolio-keyboard-local-final-full.log`.

Not shipped. App target is 0.7.16/152 on `codex/walkfolio-command-layer`; installed
0.7.15/151 remains closed. No headed/manual UI, live archive, private delivery or real
provider authorisation. Astra reviewed read-only; reported failures fixed/tested;
remaining UI control inventory and final review are in the matching specification.

Source/workspace/Settings recovery controls now registered. Inline Log details and
per-Log actions, location save/clear/retry/pin and Trip label controls retain exact
canonical targets and drafts. Field-editor ownership resolves the nearest native
container; changed text/selection, target replacement, authority generations, window
registration replacement, hidden panes and modal overlays refuse stale actions.
Astra's source review found target, reattachment and authority defects; corrected
regressions pass. Keyless Save/start-next also honours IME composition.

A hidden narrow-pane regression reproduced clipped multiline editors: native frame
width did not constrain SwiftUI fittingSize. Hosted content now measures at the
proposed width. Adaptive buttons and wrapped notes fit at 260/320/420 points. These
are layout measurements; cacheDisplay omits some native button drawing and does not
establish headed visual acceptance. Root-authority and hidden-pane defects reproduced
2 and 3 red issues; layout reproduced 5 red issues before correction.

Remaining: Walk proposal row commands, Preview/Compare crop/columns/pan/original
controls, Google Settings/job controls and review Map; captured targets throughout;
actual menu/help verification; final tests/review; signed bundle, closed install and
exact-version acceptance. Original native/real-copy/provider gates remain open.
