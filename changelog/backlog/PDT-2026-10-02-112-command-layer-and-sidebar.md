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

- Review Map: local presentation handler for the review Map button.
- Review rows/groups and Inspector crop-version navigation: retain displayed photo,
  group membership and session/source targets; preserve parent keyboard multi-selection.
- Review browser: Expand/Collapse All, grouping/filter/layout/grid size actions and
  selection/triage controls in the actual containing pane; Review Map remains local.
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

## Image commands and completion checkpoint — 2026-10-03

- Full suite: 574 tests / 2 suites, 44.515 s; 127 additions since installed
  0.7.15. This continuation adds 24 image command/completion functions.
- Actual containing Preview/Compare surfaces replace the one-point responders.
  Captured controls cover manual/visible crop, Save/Cancel/Close, navigation, shared
  zoom, pan lock, column sizing, triage/RAW, linked photo and displayed original download.
  Compare card actions retain their own photo; keyboard selection and parent Save
  retain parent intent. Unsupported child actions do not shadow parent commands.
- Initial attachment may acquire image focus; ordinary draft redraw never does.
  Native hidden hosting covers actual containers, exact handlers and command inheritance.
  Preview Inspector requires its current explicit handler in a registered Preview window.
- Image authority captures Archive/Pictures/role generation before workers start.
  Presentation revision rejects navigation, close/reopen and selection round trips.
  Successfully saved crop A is retained without replacing current photo B, focus,
  Compare membership or status. Index success/error publication respects the origin.
- Explicit original download retains its displayed photo and request lifetime; Compare
  download never opens Preview. Travel consent survives current-authority navigation.
- Native canvas callbacks retain their target and attachment revision. Disposal and
  replacement invalidate queued crop/zoom/viewport updates; consumed pan commands do
  not replay. Synchronous interaction ownership makes Cancel/Fit win before redraw.
  Geometry changes revoke retained Save commands; one drag still publishes its related
  visible/manual/zoom updates together. Crop manifests verify the current rectangle.
- Crop availability and backend acceptance share Copy/backup/import/read guards. Refused
  Save retains its draft. Compare triage filters locked imported members before mutation,
  removal or advancement; RAW additionally needs an editable companion.
- Current-session Copy entry and retained confirmation wait for active crops. Manual
  input also rechecks live eligibility before redraw while saving. Failed session save
  cannot invent an integrated crop item; on-disk output remains available for reload,
  and failure cannot replace another presentation's status.
- Red evidence: initial completion/navigation run (6 functions/39 issues); crop-index
  status and consumed-pan run (2/2); Copy/lifecycle locks (2/5); pre-redraw timing (2/6);
  Copy/draft overlap (3/9). An unrelated eager cache-warning assertion was narrowed;
  retained target/file/selection evidence remains. Corrected 19-function image focused
  run and 4-function overlap/Inspector run pass. Final full suite:
  /private/tmp/walkfolio-image-command-final-full.log.
- Astra reviewed read-only; material findings reproduced and fixed, final focused
  review clear. Synthetic JPEGs/manifests, delayed fake boundaries and hidden native
  windows only. No headed interaction, live Archive, real model/provider or delivery.
- Target 0.7.16/152 remains unbundled/uninstalled. Installed 0.7.15/151 stays closed.
  Image implementation is complete for this slice. Remaining Map/toolbar/Inspector/
  import/browser/native-menu inventory and final release work below/above stay active.
  Original native/real-copy/migration/OneDrive/LM Studio/Google acceptance stays open.

## Remaining control target audit — 2026-10-03

Implement the existing inventory without conflating its targets. Toolbar Open opens the
focused photo; keyboard Open still opens the current folder/selection. Sidebar and
Inspector workflow controls capture the displayed Log and a monotonic assignment
revision, rejecting replacement and same-UUID/ABA changes before redraw. Recheck live
eligibility before New Log, Copy, destination, backup and cleanup backends. A containing
workflow scope offers only those actions and preserves native text editing.

Review row triage/RAW/retry targets the clicked photo, while keyboard triage targets
the current multi-selection. Group Compare captures that group's membership. Inspector
crop-version navigation captures the displayed photo/session/source, never a relative
path that could resolve to a different Log. Review Map belongs to the actual containing
Review pane and inherits through the child keyboard surface. Browser/toolbar controls
use their registered window or containing target; modal overlays suppress underlying
actions. Test native text, retained callbacks and pre-redraw target/operation changes.
These controls and native menu refresh remain unfinished until verified and reported.

Astra cleanup preflight: disable cleanup during an existing cleanup and when only
retained crop originals remain. Reproduce both against the existing rules before
changing the shared candidate predicate. Keep source verification and confirmation.

## Captured workflow and window controls checkpoint — 2026-10-03

- Full suite: 586 tests / 2 suites, 47.825s. Twelve new workflow/control functions;
  139 additions since installed 0.7.15. Focused 12/3.039s; broad command/workflow
  135/26.319s before final review corrections. Final full run includes those fixes.
- Actual containing Sidebar/Inspector workflow controls retain Log assignment,
  root/Pictures/role generation and live backend eligibility. Same-ID/ABA replacement,
  before-redraw busy changes and root round trips refuse stale Copy/backup actions.
- Inbox New Log also retains creation scope, including folder selection ABA and the
  exact containing lease after redraw; four session-wide actions use session authority.
- Toolbar Open retains focused-photo intent; toolbar Deselect retains photo-only
  selection under Sidebar/folder focus and never clears selected folders. Generic
  keyboard Open/Deselect defaults keep their existing current-selection semantics.
- Main toolbar, Inspector toggle, selection/triage, Back/Return, thumbnail Prepare/
  Cancel and Archive Clear filters use the registered window route. Compare suppresses
  underlying main-only controls; native field editing retains Cmd-A/C and text selection.
- Explicit stacks/control size inside the hosting boundary preserve horizontal and
  compact vertical controls. Actual hidden hosted Sidebar/Inspector Cmd-Shift-M opens
  the correct Copy plan; measured 280/1000pt workflow layout passes.
- Cleanup disables during an existing cleanup and when only retained crop originals
  remain. UI/backend share the candidate predicate; verification and confirmation stay.
- Red evidence: unguarded current-session prototype 4 tests/5 issues; existing cleanup
  eligibility 2/4; reviewed Deselect/layout/inbox scope 3/8 after fixture correction.
  AX/native NSButton traversal was unavailable in closed windows; final layout evidence
  is hosted fitting-size measurement, not headed visual acceptance. Astra review clear.
- Logs: /private/tmp/walkfolio-session-controls-{before,cleanup-before,review-before,
  final-focused,final-full}.log. Original whole-workflow acceptance remains open.
- Target 0.7.16/152 remains unbundled/uninstalled. Complete Review Map/control/row/group/
  crop-version and native menu inventory before final release; installed 0.7.15/151 closed.


## Review pane implementation intent — 2026-10-03

Contain the actual Review top bar, Map, grid/list and keyboard child in one owned
Review surface that fills the available height. Map becomes keyless and rebindable.
Display, grouping, filtering, layout, column size, selection, triage and expansion
controls execute registered commands through the clicked containing capability.
Pane identity changes on Log/source, workspace and sidebar navigation, including
ABA round trips. Ordinary selection, triage, filters and layout retain this generic
pane capability; per-photo controls will use separate strict targets in the next
slice. Recheck live eligibility before execution. Preserve the keyboard child's
selection/advance behaviour and photo-only Deselect. Empty filter results must
retain filter/layout recovery controls.

Explicit focus after a control action belongs to the keyboard child of that exact
Review container. Queued requests recheck both owner and final target, visibility,
ancestry and current modal boundary; an absent explicit child fails closed. No
redraw reacquires focus. Tests cover hidden native event routes, text editing,
retained child after parent replacement, source/navigation/authority ABA, current
selection, bounds, modal/hidden/detached focus races and actual hosted grid height.
Primary codes/tests; Astra reviews read-only. Still unbundled 0.7.16/152.


## Review controls verified checkpoint — 2026-10-03

- Fourteen new functions. Final full suite: 600 tests/two suites, 53.769s; 153 additions
  since installed 0.7.15. Actual contained Review fills the window with Map shown,
  focuses its keyboard child after layout changes and dispatches native Arrow/Space.
- Pane/context, empty-result recovery and exact executing-owner checks validated.
  Initial queued focus: four functions/five issues. Deliberate guard reversal:
  three functions/fifteen issues. Synchronous owner removal: one function/four issues.
- Astra reviewed read-only; final ownership finding reproduced/fixed and review clear.
- Continue captured photo rows/group membership/Inspector crop versions and legacy
  section controls, native menu refresh/inherited binding/help inventory, then final
  review/full tests and signed closed install. Original acceptance gates remain open.
- Target 0.7.16/152 is still unbundled/uninstalled; installed 0.7.15/151 remains closed.


## Captured photo/group/version implementation intent — 2026-10-03

Capture exact displayed photo values, pane/session assignment and display membership
for row triage/RAW, Retry, linked crop badges and grid click selection. Unrelated
photo selection does not revoke a row button; Log/source/filter/group replacement
and copy/lifecycle locks do. Preserve select-exact-row then backend triage/advance.
RAW setters preserve the requested Boolean. Native action bars and individual Retry/
badge controls offer explicit keyless photo commands; inherited Review commands
remain on their parent. Thumbnail lifetime/appearance work stays outside commands.

Group headers capture current organised section identity, ordered membership/title/
kind and exact compared photo values. Resolve the current visible section before
Compare/focus/toggle; expansion remains live. Inspector crop versions capture the
displayed source photo plus exact loaded version ID/path/value and history membership.
Eliminate path-only UI opening and keep current/not-loaded eligibility.

Focus restoration uses the exact captured executing ancestor chain. Replacing an
unrelated row must not cancel a stable Review-ancestor request; replacing the target
or its ancestor must. Validate the queued target chain and keyboard descendant.
Keep native text/keyboard semantics, grid/list dimensions and large-session lookup
cost bounded through shared membership indexes. No dependency, headed UI or live
Archive/provider operations. Primary implements/tests; Astra consults read-only.

Regression conditions: reused IDs/filenames across Logs and ABA before redraw,
changed item/lifecycle/Copy eligibility, filter/collapsed-group removal, exact RAW
values, Retry/linked-crop ownership, changed group membership, Inspector selection
round trips, actual hosted native button scopes/layout/keyboard inheritance, and
ancestor focus when a clicked row is replaced. Still unbundled 0.7.16/152.


## Captured Review target checkpoint — 2026-10-03

- Actual row triage/RAW/Retry/crop badges, group focus/expansion/Compare and Inspector
  crop-version controls now retain UI-issued context and exact displayed targets.
- Shared membership cache follows filters and collapsed groups; 30,000-photo fixture
  performs 500 checks in 25ms. Row action selection independence and RAW Bool preserved.
- Exact original focus ancestry, inherited photo-selection ownership, coactive shortcut
  validation, fresh Inspector epochs and thumbnail-failure presentation corrected.
- Red evidence: original target seam 7 functions/14 issues; later focus/thumbnail 2/2;
  inherited keyboard/shortcuts 2/4; Inspector context 1/6. Astra final review clear.
- Final full suite 622 tests/two suites, 68.142s; 22 new functions and 175 additions since
  installed 0.7.15. Actual hidden grid/list host dimensions/actions and native shortcuts
  verified; no headed/native/provider acceptance implied.
- Continue legacy unused-section inventory and native menu refresh/effective inherited
  bindings/help; then final whole-inventory review/tests, signed bundle/body verification
  and closed installation. Original full-scope acceptance gates remain active.
- Target 0.7.16/152 stays unbundled/uninstalled; installed 0.7.15/151 unchanged and closed.
