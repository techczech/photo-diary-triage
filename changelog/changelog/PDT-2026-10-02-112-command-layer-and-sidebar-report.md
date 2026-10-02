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
Content/Archive/Settings/Google/description/review views; five command test files, GooglePhotosTests and DescriptionTests;
APP_RELEASE.env and matching tracking. No new dependency.

Full verification: 550 tests / 2 suites, 38.279 s: 76 command-file functions plus 14 new Google
callback functions and 13 new description functions (103 additions since installed 0.7.15). Native
hidden windows, real NSTextView/NSTextField editor and NSWindow event paths. Distinct
pre-fix logs plus deliberate sheet/IME guard reversal prove the defects are detected.
Final run: `/private/tmp/walkfolio-description-command-final-full.log`.

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

Remaining: Preview/Compare crop/columns/pan/zoom/original and crop-completion focus;
review Map; toolbar/Inspector/selection/triage; Source/import actions; browser Back/filter/
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
