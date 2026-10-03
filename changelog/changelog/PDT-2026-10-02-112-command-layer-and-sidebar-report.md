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
Content/Archive/Settings/Google/description/review views; five command test files, GooglePhotosTests, DescriptionTests and ImageCompletionTests;
ImageCommandActions/ImageOperationContext/CropService/ArchiveIndex;
APP_RELEASE.env and matching tracking. No new dependency.

Full verification: 574 tests / 2 suites, 44.515 s: 76 command-file functions plus 14 new Google
callback functions, 13 new description functions and 24 image command/completion functions
(127 additions since installed 0.7.15). Native
hidden windows, real NSTextView/NSTextField editor and NSWindow event paths. Distinct
pre-fix logs plus deliberate sheet/IME guard reversal prove the defects are detected.
Final run: `/private/tmp/walkfolio-image-command-final-full.log`.

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
