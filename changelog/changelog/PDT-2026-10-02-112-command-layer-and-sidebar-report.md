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
Content/Archive/Settings/Google/description/review views; command test files, SessionWorkflowCommandTests, ReviewPaneCommandTests, GooglePhotosTests, DescriptionTests and ImageCompletionTests;
ImageCommandActions/ImageOperationContext/CropService/ArchiveIndex/SessionWorkflowCommands/ReviewPaneCommands;
APP_RELEASE.env and matching tracking. No new dependency.

Full verification: 622 tests / 2 suites, 68.142 s: 124 command-file functions plus 14 new Google
callback functions, 13 new description functions and 24 image command/completion functions
(175 additions since installed 0.7.15). Native
hidden windows, real NSTextView/NSTextField editor and NSWindow event paths. Distinct
pre-fix logs plus deliberate sheet/IME guard reversal prove the defects are detected.
Final run: `/private/tmp/walkfolio-review-targets-final-full.log`.

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

Containing modal roots now hold actual child controls. Nearest focused rows retain
local commands and explicitly offered parent Confirm/Close; disabled child handlers
block fallback. Button/palette capabilities capture every exact ancestor lease and
reject parent draft round trips/reparenting. Window registration remains stable while
leases change. Coactive parent/child shortcut assignment and restored collision paths
fail closed. Contextual discovery includes explicitly offered parent actions.

Copy-plan Merge/Split capture the actual Walk UUID/draft and preserve canonical Trip
identity and recovery locks. Hidden tests mount the real copy-plan SwiftUI sheet and
verify rendered nested buttons through first attachment, draft change and reattachment.

Google settings, reviewed Send and queue/job/album controls are registered. Job/account
capabilities include authority generation and exact revision; awaited results cannot
publish jobs, status, candidates or account into another context. Current review identity
prevents retained confirmation from sending a cancelled/replacement review. Unique pending
review requests keep the latest request and expire at delivery start, including when
delivery finishes before the old callback returns. Explicit album adoption never starts
sending; absence still requires the native alert's confirmation. Failed credential saves
retain the entered draft; command context keys contain no secrets.

Pre-fix logs reproduced: hierarchy (3 issues), discarded Google confirmation (5), stale
Google publication (5), pending/out-of-order reviews (4), post-delivery review (1), and
Settings Form overflow (1). Actual hosted Google album/job/queue chains are verified;
scrollable Settings honours the proposed tab height. Native hidden layout is measurement,
not headed visual acceptance. Astra final focused review found no unresolved delta.

Files added: GooglePhotosCommands.swift, CommandHierarchyTests.swift, GoogleCommandTests.swift.
Changed: AppCommandRegistry, AppState, CommandKeyboardRouting, CommandLocalSurface,
CommandPaletteView, ContentAuxiliaryViews, GooglePhotosViews/Delivery, existing command
and GooglePhotos tests; same target APP_RELEASE.env remains 0.7.16/152.

Remaining: review Map; toolbar/Inspector/selection/triage; Source/import actions; browser Back/filter/
grid/thumbnail controls; native menu/help evidence. The full current inventory is in the spec.
Final complete review/tests, signed bundle/body verification, closed install and exact-version
acceptance remain. Original native/real-copy/provider gates stay open.

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


## Captured workflow and window controls

Session workflow controls in Sidebar and Inspector capture a monotonic Log assignment
revision and Archive/Pictures/role generation. Copy, backup, destination, cleanup and
New Log recheck their live eligibility before the backend. Retained A controls cannot
follow B, same-UUID replacement or ABA before redraw. Inbox creation also captures its
folder/review scope; replacing the containing lease rejects an old handle after redraw.
Current-session assignment and folder-selection invalidation are O(1), without a full
Log equality comparison. Ordinary keyboard text selection/copy remains native.

Main toolbar/Inspector and header/browser controls now use the registered route, including
Back/Return, thumbnail Prepare/Cancel and Clear Archive filters. Keyless focused-photo
Open and photo-only Deselect preserve distinct toolbar intent while the generic current-
selection keyboard commands keep their existing defaults. An initial Deselect mapping
followed the focused pane and cleared folders; source review and a four-issue regression
caught it. Explicit layout inside the hosting boundary corrects non-compact vertical
stacking; one measured-layout issue reproduced. Three assertions reproduced retained
inbox creation following a different folder, including ABA and borrowing a new action.

Published cleanup busy state disables duplicate cleanup. The candidate predicate shared
by eligibility and the backend retains originals with crops. Both prior eligibility
failures reproduced two issues each. The initial unguarded current-session prototype
reproduced five issues in four functions; capture/live checks correct them. These are
synthetic fixtures and hidden native windows, with no destructive dialog or live delivery.

Twelve new functions pass in 3.039s; final complete suite 586/2 suites in 47.825s. Actual
hosted Sidebar/Inspector Cmd-Shift-M opens the correct Copy plan. Field-editor and Compare
fixtures protect text and underlying controls; layout measurements cover 280/1000pt.
Native NSButton/AX traversal omitted hidden SwiftUI controls, so no pixel/position or
headed visual acceptance is claimed. Astra's final scoped source review is clear.

Remaining: actual containing Review Map/group/filter/layout/grid/selection actions;
photo rows/groups/Inspector crop versions; native menu refresh/inherited bindings; final
whole-inventory review/full tests and signed closed installation. Original native/real-
copy/migration/OneDrive/model/Google acceptance stays open. Not bundled or installed.


## Containing Review controls and focus

The actual Review top bar, Map and scrolling grid/list now share one containing
registered surface with available-height sizing. Map is keyless, discoverable and
rebindable; display, grouping, filters, layout, grid size, selection, triage and
expansion use the clicked capability. Per-mode command IDs avoid independent mouse
logic. Photo-only Deselect preserves folder selection and keyboard triage still
advances through the actual keyboard child's callbacks. Empty filtered results keep
filter/layout recovery commands available through the original photo context.

Generic pane identity changes on Log/source/workspace/sidebar navigation, including
ABA before redraw. Selection, triage and ordinary saved metadata preserve the pane
lease and apply the current photo selection. Live eligibility is rechecked before
the backend. Authority generations remain part of the captured capability.

Focus requests capture the exact registered lease and native target. Explicit child
providers fail closed; owner/target visibility, window, descendant ancestry, modal
boundary and replacement are rechecked at queued execution. The synchronous command
retains its exact executing owner only until defer, choosing its own grid over a
newer Review container and refusing restoration if the action removes its owner.
Ordinary updates do not reacquire focus; native Map text typing/selection/copy and
generated Help remain intact.

Verification: fourteen new functions; full suite 600 tests/two suites in 53.769s.
Initial queued-focus tests reproduced five issues in four functions. Deliberate
context/empty-result/owner-preference guard reversal reproduced fifteen issues in
three functions. Astra's synchronous unregister/detach finding reproduced four
issues in one function before the final fix. The actual hosted Review retains its
window height with Map shown and its keyboard child after switching to list; real
NSWindow Arrow/Space events move and toggle the photo selection. Separate tests
cover competing containers, retained child after parent replacement, current photo
selection, bounds, field editor, navigation/source/authority ABA and queued races.
Astra's final scoped source/test review clears the material finding; this is a
read-only model review, while execution evidence comes from primary's test runs.

Logs: `/private/tmp/walkfolio-review-focus-before.log`,
`/private/tmp/walkfolio-review-controls-guard-reversal.log`,
`/private/tmp/walkfolio-review-owner-removal-before.log`,
`/private/tmp/walkfolio-review-controls-focused.log` (thirteen functions before the
last owner-removal fix) and `/private/tmp/walkfolio-review-controls-final-full.log`.
The first live-selection fixture expected the original photo after intentional
triage advance; the final fixture explicitly selects the next current photo.

Remaining: captured photo-row triage/RAW/retry, group Compare membership, Inspector
crop-version targets and unused legacy section controls; native menu refresh and
inherited effective bindings/help; final whole-inventory review and signed closed
installation. Original native/real-copy/migration/OneDrive/model/Google acceptance
remains open. Target 0.7.16/152 remains unbundled/uninstalled; installed 0.7.15/151
verified closed. No headed screen, live Archive, provider authorisation or delivery.


## Captured Review photos, groups and crop versions

The actual grid/list triage, RAW setters, failed-thumbnail Retry and crop-link badges
now retain the displayed photo value and the UI-issued ownership epoch. Row actions
ignore unrelated selection changes but reject changed Logs/sources/authority, exact
photo replacement, filters/collapsed groups, overlays and Copy/lifecycle locks before
selecting or mutating. RAW uses distinct include/exclude commands to preserve the
requested Bool. Grid selection and the native List binding also retain pane context.
Background thumbnail appearance is guarded by the same captured target.

Group focus/expansion and Compare retain the displayed section identity, ordered
membership and member values. Inspector crop versions retain both the displayed
source and the exact loaded photo UUID/path/value and history membership; mouse
controls no longer resolve a filename into a newer Log. Current and unloaded versions
remain disabled. Failed thumbnail state now reaches and refreshes the Inspector.

Inherited native Review shortcuts resolve their containing handler before activating
photo selection. Row/group scopes declare Review coactivity so Settings rejects a
binding that would shadow an inherited command. Queued focus retains the original
execution ancestry, while replacing an unrelated photo row no longer cancels the
stable containing Review request. Fresh Inspector context follows Preview/Compare and
pane changes, and excludes unrelated Review layout/filter cache state.

Verification: 22 new functions; full suite 622 tests/two suites in 68.142s. The first
seven target tests reproduced 14 issues against an unguarded factory mirroring the
previous UI callbacks. Two later failures exposed replaced focus ancestry and missing
Inspector thumbnail refresh. Native inheritance/shortcut tests reproduced four issues
in two functions; UI-issued Inspector epoch tests reproduced six issues in one function.
All corrected cases and positive workflows pass. Actual hidden hosted grid/list controls
retain dimensions and act on their displayed photo after selection changes. Native
Cmd-I/Cmd-Shift-X from row/group controls with prior sidebar/folder focus changes only
the selected photo. A 30,000-photo shared membership index performs 500 target checks
in 0.025020042s in the full run (0.02325675s in focused verification).

Logs: `/private/tmp/walkfolio-review-targets-before.log`,
`/private/tmp/walkfolio-review-targets-extra-before.log`,
`/private/tmp/walkfolio-review-targets-inheritance-red.log`,
`/private/tmp/walkfolio-review-targets-inspector-context-before.log`,
`/private/tmp/walkfolio-review-targets-final-focused.log` (22/10.908s), and
`/private/tmp/walkfolio-review-targets-final-full.log` (622/68.142s). The initial burst
fixture was corrected to assign its member photos before collecting valid red evidence.
Astra's final read-only source review clears its concrete findings; test execution is
primary evidence. No new dependency, headed window, live Archive or real provider use.

Remaining: legacy unused section-control inventory; native menu refresh/effective
inherited bindings/help; final whole-inventory review and signed closed installation.
Original native/real-copy/migration/OneDrive/model/Google acceptance remains open.
Target 0.7.16/152 is unbundled/uninstalled; installed 0.7.15/151 remains closed.
