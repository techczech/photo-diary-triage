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

Keep `implementation_in_progress`. The complete control inventory still has executable
buttons/menu actions outside the shared path; the registered backend alone does not
establish their mouse/keyboard agreement. Do not bundle/install or mark this item done.

- Preview/Compare: manual crop toggle/save/cancel, Compare columns/pan lock, shared
  zoom strip, explicit Download to view targeting the displayed/focused photograph.
- Review Map: local presentation handler for the review Map button.
- Main toolbar/Inspector: sidebar, Open, Compare, Inspector and selection/triage menus;
  inspector show/hide controls. Use actual local targets where actions offer a row.
- Source/import: New Log, Copy, Open Archive destination, Confirm Backup and Cleanup
  in ContentViewSections and ContentInspectorWorkflowViews.
- Browser: Back/Return to search, Expand/Collapse All, grid size actions, selection/
  triage controls, thumbnail Prepare/Cancel; Archive Clear filters.
- Image completion ownership: preserve saved crop A without stealing focus/Preview
  from B after navigation; gate current-context publication and index refresh. Explicit
  Download to view must retain the actual displayed/focused item and its presentation.
- Menus/help: verify native refresh and inherited scoped bindings; rendered native
  menu behaviour is an acceptance candidate, not established by source declarations.
- Final complete inventory/Astra review, full suite, signed bundle/body comparison,
  closed installation, immutable exact-version acceptance and final tracking remain.
- Original native/real-copy/historical migration/OneDrive/LM Studio/Google provider
  and quality acceptance remains required. Headed tests require Dominik watching.

## Captured local control checkpoint — 2026-10-02

- Full suite: 505 tests / 2 suites, 30.799 s; 58 command test functions total.
- Source, Settings, workspace, Finder and retry commands registered; 15 new keyless IDs.
- Log details/start-next capture UUID and draft; per-Log contents/details/membership/
  add-marked/delete/continue retain UUID and imported membership locks.
- Location save/clear/retry/map-centre and Trip edit/save/use-Walk/cancel controls retain
  canonical targets, root and drafts. Canonical Trip replacement resets editing.
- Nearest native container owns a shared field editor, independent of registration
  order. Native text, selection and IME are protected in every added editor scope.
- Button capabilities retain issuing authority generation/window registration; target
  and draft changes replace the exact lease. Reattachment rebuilds current buttons;
  retained old callbacks, hidden panes and modal overlays cannot mutate editors.
- Root round trip: 1 test / 2 red issues; hidden ancestor: 1 / 3 red issues. Narrow
  layout: 1 / 5 red issues; proposed-width SwiftUI measurement corrects clipped fields.
- Evidence: /private/tmp/walkfolio-keyboard-local-final-full.log;
  walkfolio-keyboard-local-before.log, walkfolio-keyboard-local-authority-before.log,
  walkfolio-keyboard-local-authority-layout-after.log (red layout),
  walkfolio-keyboard-local-layout-after.log, walkfolio-keyboard-local-hidden-before.log.
- Hidden layout at 260/320/420 points; no headed visual acceptance. Astra local source
  review clear. Remaining proposal/crop/Google/view/menu/help/release work still active.
- Target remains 0.7.16/152 on codex/walkfolio-command-layer. No bundle or install.
  Installed 0.7.15/151 remains closed; original native/real-copy/provider gates open.

## Containing modal and child command ownership

Copy-plan rows and delivery jobs are actual containing native command surfaces. The
most-specific focused child owns its actions; explicitly offered ancestor Confirm/Close
commands remain available. Disabled child handlers prevent ancestor fallback. Button and
palette invocations retain the exact complete ancestor capability chain; replacing a
parent draft, reparenting or detaching invalidates retained commands. Window registration
survives ordinary draft lease replacement. Coactive parent/child shortcut collisions are
rejected on assignment and fail closed when restored. Plain Return and native text
editing retain their existing meaning in a focused row editor. Hidden native fixtures
cover this hierarchy, stale ancestors, siblings, disabled shadowing and collision paths.

## Containing copy-plan and Google checkpoint — 2026-10-02

- Full suite: 530 tests / 2 suites, 35.504 s. 72 command-file test functions and
  11 new Google provider/callback functions: 83 additions since installed 0.7.15.
- Actual containing modal roots retain stable window registration while semantic
  drafts replace leases. Child buttons/palette actions capture the exact complete
  ancestor chain; disabled handlers shadow parents; siblings never lend authority.
- Copy-plan rows capture Walk UUID and edited draft; Merge/Split preserve canonical
  Trip targets and recovery locks. Actual hosted row/parent keyboard and rendered
  buttons tested through initial mount, draft replacement and detach/reattach.
- Google settings, reviewed Send, queue/job/album controls use registered actions.
  Client/account generations reject round trips; asynchronous handlers revalidate
  targets before provider work and before publishing success/error/progress.
- Discarded/replaced review cannot send; pending request identity rejects out-of-order
  reviews and callbacks after delivery starts/finishes. Album selection stays explicit;
  absence review still requires the native confirmation alert. No automatic resend.
- Credential save failures retain the entered draft. Secrets never enter command
  context keys; only synthetic fixture credentials/provider services used in tests.
- Actual hosted Google queue verifies album -> job -> information capabilities.
  Settings Form overflow reproduced, then proposed-height layout corrected.
- Pre-fix evidence: hierarchy-before (3 issues); google-review-before (5),
  google-publication-before (5), google-pending-review-before (4),
  google-busy-review-before (1), google-hosting-before (1 layout issue).
- Final: /private/tmp/walkfolio-keyboard-hierarchy-google-final-full.log. Astra final
  focused review clear. No native menu acceptance, bundle/install, headed launch,
  live archive, real authorisation, private delivery or watcher. Target remains
  0.7.16/152; installed 0.7.15/151 verified closed. Remaining inventory above is active.

## Description and command preparation checkpoint — 2026-10-03

- Full suite: 550 tests / 2 suites, 38.279 s. 103 additions since installed
  0.7.15: 76 command-file functions, 14 new Google callback functions and 13 new
  description functions. Twenty additions in this continuation.
- Registry preparation captures selection/account/root/model before Task scheduling.
  Changed Log/entry/map Walk cannot supply another review or local upload mark.
  Map selection identity is now part of the authority fingerprint.
- Description requests capture paths/year and model configuration synchronously and
  reserve one owned operation through preparation, jobs, progress and automatic run.
  Cancellation revisions span preparation; repeated Cancel acknowledgements are
  chained before fresh Resume. Awaited jobs/errors cannot publish into a root round trip.
- Discard has a retained task and synchronous ownership; cancellation reaches durable
  write guards. A first discarded receipt records whole-batch intent: unfinished siblings
  remain logically inactive across reloads; committed results remain committed; explicit
  retry completes the raw receipts. Partial Cancel cannot strand pending parents or
  accidentally Resume a discarded batch. No recovery schema change.
- Year enumeration retains the issued model/endpoint. Model refresh success/error and
  retained Settings controls reject endpoint/configuration round trips.
- Actual description queue and Local AI Settings contain their controls. Local queue
  presentation requires a successful current read. Real Settings field editors retain
  their nearest local lease while native Select All/Copy and IME protections remain.
- Default SSD/Archive root, app backup and Archive Describe buttons route through the
  shared registry. Settings/editor scopes admit their actual owner; Form tab height is
  measured at 580x380 in hidden native hosting. No file panels or real model/provider requests.
- Before-fix evidence: changed selection 2 tests/4 issues; description ownership
  6 tests/14 issues; repeated Cancel 1/3; map target 1/1; Settings scopes 1/13;
  hosted ownership 4/3; model round trip 1 parameterised/3; cancelled Discard 1/1;
  interrupted batch 1/2 with the recovery repair deliberately removed, then restored.
- Final: /private/tmp/walkfolio-description-command-final-full.log. Astra final focused
  source/test review clear. Tests use synthetic canonical photos, fake model/provider
  boundaries and hidden windows; no live data, authorisation or headed interaction.
- Target remains 0.7.16/152, unbundled/uninstalled; installed 0.7.15/151 verified closed.
  Remaining image/view/toolbar/import/browser/menu/release work above stays active.
