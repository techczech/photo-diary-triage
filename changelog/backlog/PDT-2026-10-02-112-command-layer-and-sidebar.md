---
item_id: PDT-2026-10-02-112
title: Complete command layer and owned keyboard navigation
status: implementation_in_progress
target_release_version: 0.7.16
target_build: 152
target_feature_slug: command-layer-and-sidebar
source: Original keyboard-first triage, WP3 sidebar usability and keyboard-and-commands contract
---

# Find and run every command from the keyboard

Dominik authorises independent development towards the complete reliable photo diary
workflow. The keyboard audit found duplicate focus/grouping chords, reserved-key conflicts,
hard-coded help, broad modifier matching, unowned sidebar searches and redraw-triggered
focus stealing. Implement the whole command layer and actual native event/focus paths.

## User experience and implementation intent

A searchable command palette opens with Cmd-Shift-P; contextual actions with Cmd-K.
Commands have stable IDs, user-facing names, task groups, explicit defaults or no default,
context/availability reasons and one execution route. Menus, native handlers, palette,
contextual menus and generated Cmd-/ help resolve the same effective persisted bindings.
Every command is listed and bindable; overrides distinguish default, unbound and assigned,
replace old aliases, reject collisions/reserved misuse, retain unknown records safely and
surface persistence errors. Cmd-Shift-Comma rebinds the highlighted palette command.
Settings remains Cmd-Comma. Cmd-P toggles the existing inspector, retaining its registered
legacy default alias until overridden. Find/search remain default-on. Cmd-Shift-K stays
reserved and unbound: no locked journey currently requires a new navigation switcher.

Preserve existing nonconflicting shortcuts. Focus Ctrl-Cmd-1/2 wins the two existing
ambiguous grouping collisions; those grouping modes are palette-listed/keyless/rebindable.
Cleanup moves from reserved Cmd-Shift-K to Option-Cmd-K. Go Up yields Cmd-Up to standard
text navigation. Record all collision outcomes. No hyper or Control-arrow assignment;
unclaimed native text movement and Shift extensions remain intact.

Help/palette presentation is coordinated per invoking owned window, including Settings
and editor sheets, independently of those sheets. Capture the original window, actual
editing control/selection and immutable invocation context. Revalidate context before
commands run; restore focus only to a still-valid origin if no deliberate focus change
intervened. Escape acts on the top command/capture/composition surface only.

Route actual events through owned window and most-specific responder/scope leases, with
exact modifiers and one dispatch. Compare/Preview suppress underlying review commands.
No redraw reacquires focus: explicit cancellable focus requests revalidate owner, lease,
window, modal state and context. Sidebar gets its own native container/target; never find
a table across the window. Archive cursor identity is separate from active kind/year
filters, survives list refresh, scrolls into view, and arrows/Enter operate consistently.

## Meaningful tests

First reproduce actual ReviewKeyResponderView modifier/focus defects with synthesized
NSEvents in hidden windows. Then test reserved defaults, overlapping-scope/alias collisions,
override persistence and failure, every command discoverable/bindable, generated help/menu
agreement and dispatch through the installed native path. Real NSTextField field editor
and multiline NSTextView fixtures cover typing, Cmd-/ and palette, editor sheets/Settings,
focus/selection restoration and untouched macOS movement. Cover actual review selection,
Compare and Preview commands, palette search/highlight/rebind/capture/cancellation, stale
origin/root/selection, delayed focus races, two windows, replaced leases, owned sidebar
navigation and mismatched/modified keys. Reinstate key guards to prove regressions fail.
Run full suite, Astra source review and real signed bundle installation while closed.

## Constraints and success criteria

Primary implements; Astra reviews read-only. Use existing Swift/AppKit/SwiftUI and Swift
Testing, no new dependency. Design uses native searchable command panels and existing
pane layout; it introduces no unrelated redesign. Tests never order/activate windows or
take over the screen. No live archive mutation/private delivery/provider authorisation.
All command surfaces share effective bindings and eligibility; focus belongs to the
visible invoking surface, typing cannot mutate hidden review and commands are findable.
Original whole-workflow native/real-copy/OneDrive/LM Studio/Google gates remain explicit.
Dominik has delegated routine design choices; this concrete spec proceeds independently.


## Verified development checkpoint — 2026-10-02

- Branch: `codex/walkfolio-command-layer`; base `057fadc`.
- Target: 0.7.16/152. Installed: 0.7.15/151, closed; no new bundle/install.
- Full suite: 491 tests / 2 suites, 25.921 s. New keyboard functions: 44.
- Exact modifiers; override/reset persistence; reserved and alias collisions; native text
  editing; shared field editor ownership; stale context/root/lease; two windows; IME;
  deferred focus; owned Archive sidebar and measured cards; Find; Preview triage;
  registered forms/capture; sheet dismantling; contextual folders; generated scoped hints.
- Actual production Review callback/redraw tested after another window focuses Sidebar.
- Windowless startup crash reproduced and fixed. Lifecycle/focus tests: 3 tests / 10 red
  issues. IME/typing tests: 2 / 31 red issues. Shared selection: 1 / 2 red issues;
  stronger production redraw: 1 / 2 red issues. Sheet/IME fixes deliberately removed,
  2 tests / 5 issues reproduced, then restored. Hidden native windows only.
- Evidence: `/private/tmp/walkfolio-keyboard-checkpoint-112.log`;
  `walkfolio-keyboard-windowless-before.log`, `walkfolio-keyboard-lifecycle-before.log`,
  `walkfolio-keyboard-text-before.log`, `walkfolio-keyboard-owned-selection-before.log`,
  `walkfolio-keyboard-owned-redraw-before.log`, `walkfolio-keyboard-sheet-lifetime-before.log`.

## Remaining implementation before release

Astra's complete control inventory found additional actions that bypass the registry.
Keep this item `implementation_in_progress`; do not install/report complete until routed.

- Source/Settings: historical source picker; default source/reload; synced Photo Log
  import; model refresh. Candidate IDs: `chooseHistoricalSource`, `openDefaultSource`,
  `reloadSource`, `importSyncedPhotoLogs`, `refreshDescriptionModels`.
- Photo Logs: contents/details/membership/add-marked/delete; inline draft Save and
  Save/start-next; open Logs. Capture selected Log UUID/draft, reject stale replacement;
  preserve imported-log guards. Candidate IDs: `showPhotoLogContents`,
  `editPhotoLogDetails`, `editPhotoLogMembership`, `addMarkedToPhotoLog`, `deletePhotoLog`,
  `saveLogDetails`, `showPhotoLogs`, `saveLogAndStartNext`.
- Locations: Map save/clear/retry, Trip edit/save/use Walk locations; inline-owned leases,
  not window-owning sheet anchors. Capture actual assignment target and local draft.
- Walk copy proposal: merge/split; preserve recovery-plan locks and actual selected row.
- Preview/Compare: manual crop toggle/save/cancel; Compare columns and pan lock;
  explicit Download to view must target displayed/focused photo, not hidden selection.
- Google: connect/cancel/disconnect/status; job-scoped album lookup/abandon/review absent
  album. Keep sending originals keyless, reviewed and provider confirmation boundaries.
- Navigation/view: Archive Map, review Map, Source/Logs/Archive workspace commands,
  selected-folder Finder, folder/search retry. Keep configuration values/mouse target
  selection/native alert grammar separate from commands.
- Route toolbar/context/buttons through the registry with explicit target capability.
  Generated hints now use scoped effective bindings; inspect rendered help offscreen.
- Test changed editor text/selection, shared field-editor reuse, binding capture cancel
  override, selected modal/local target, disabled/stale controls and actual menu refresh.
  The SwiftUI app's generated-menu refresh is a native verification candidate, not a
  proven source defect; do not claim it exercised without evidence.
- Final Astra review, full suite, signed bundle/body verification, closed installation,
  exact-version DTC return checks and complete report/index updates remain.
- Original native/real-copy/OneDrive/LM Studio/Google acceptance remains required.
