---
title: Walkfolio development report through version 0.7.16
date: 2026-10-03
status: frozen_for_user_review
app_version: 0.7.16
app_build: 152
tested_source_commit: ad75217576c70a2c69889b8888fe53a7ea203faf
review_checkpoint_commit: df409bb
baseline_tests: 190
final_tests: 658
development_goal: paused_by_user
---

# Walkfolio development report

**Walkfolio 0.7.16, build 152, is installed for your review. Development is paused at your request.** This report covers the independent work on 2–3 October 2026, from reviewing the existing app and recovering your aims to the frozen review build. It describes what changed, why it changed, how I tested it and what remains unfinished.

- I recovered the complete photographic-life workflow from your existing product records, including Sources, Walks, physical Trips, historical folders and index-only Travel.
- I implemented thirteen successive installed builds, covering archive safety, recovery, locations, historical triage, descriptions, Google Photos delivery, backups, navigation and the command layer.
- The full automated suite grew from **190 to 658 tests**, a net addition of **468**. The final source passed all 658 tests in two suites in 95.350 seconds.
- The review build is mechanically verified, but **the whole objective is not complete**. Several Archive/Log/inspector controls remain unfinished, and native, real-copy, OneDrive, LM Studio and live Google acceptance remain open.

The primary agent performed the implementation and test runs. Astra provided repeated read-only reviews. Claude Opus gave an earlier opinion from a bounded public-source packet. Neither model consultation establishes runtime correctness.

## Your intended outcome and the decisions I recovered

Your aim is broader than choosing good photographs. Walkfolio should help you manage new camera and phone material alongside an older archive, retain the decisions and stories attached to it, and make that archive useful on a travel Mac without downloading originals during ordinary browsing.

I reviewed the dictated scope, product context, PRD, design, approved completion plan, archive decisions and existing tracking. I consolidated their requirements into a [development plan](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/planning/development-plan-walkfolio-reliability.md) and a [requirements audit](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/planning/audit-walkfolio-completion-requirements.md), rather than treating the latest defect as the whole product goal.

The domain model remained central. **Sources** are the material brought into a Photo Log. A **Walk** is an outing and can combine camera and phone sources. Several Walks can occur on one day. A **Trip** is a physical grouping of Walks in the archive. The plain month is the settled default Trip; named, existing and new Trip targets remain available. I corrected contradictory summaries that implied a different default without changing the settled behaviour.

The archive remains a normal folder tree with readable canonical records. Markdown manifests and recorded events carry durable meaning; SQLite and the pinned JSONL index are rebuildable projections. Unorganised historical folders remain browseable alongside recognised Trips. A folder does not become a Trip merely because its name or depth looks plausible.

I retained the approved locations, explicit local descriptions, Google Photos delivery, historical triage and backup requirements. I also retained the agreed exclusions: editing beyond the existing crop workflow, GPX correlation, semantic search and ratings were not added to this effort.

## Release progression

Each row records a build installed during the work and its complete test-suite result at that stage. Earlier results are historical checkpoints; the final result is 658 tests. Test totals are not percentages of product coverage.

| Version | Build | Main change | Full suite | Net additions |
|---|---:|---|---:|---:|
| 0.7.4 | 140 | Recoverable import, verified cleanup, canonical metadata, moves and index publication. | 225 | 35 |
| 0.7.5 | 141 | Travel browsing, grids and search from the pinned index alone. | 235 | 10 |
| 0.7.6 | 142 | Archive-wide Map and explicit per-original Travel viewing. | 249 | 14 |
| 0.7.7 | 143 | Recoverable Walk, photo and shared-group location assignments. | 261 | 12 |
| 0.7.8 | 144 | Historical keep-all triage, date provenance and confirmed Copy recovery. | 279 | 18 |
| 0.7.9 | 145 | Canonical Trip location labels, membership and mixed-layout migration recovery. | 297 | 18 |
| 0.7.10 | 146 | On-demand photo/Walk/Trip descriptions and recoverable historical batches. | 321 | 24 |
| 0.7.11 | 147 | Reviewed Google Photos delivery and the composed fixture journey. | 350 | 29 |
| 0.7.12 | 148 | Complete app-state backups and recoverable two-store restoration. | 384 | 34 |
| 0.7.13 | 149 | Measured Archive navigation, Back/Open, Map selection and cached projections. | 401 | 17 |
| 0.7.14 | 150 | Visible exact-photo search, folder failure/Retry and refresh-safe selection. | 423 | 22 |
| 0.7.15 | 151 | Bounded asynchronous prepared-cover loading and decoder corrections. | 447 | 24 |
| 0.7.16 | 152 | Registered commands, shortcut settings, owned focus and captured controls. | 658 | 211 |

The last build contains the tested source at `ad75217`; `df409bb` records the freeze and verified installation. The installed feature marker is `command-layer-and-sidebar`. The review checkpoint is on the existing development branch, `codex/walkfolio-command-layer`; it was pushed there. The command work was not merged into the main branch during this wrap-up.

## Import, cleanup and archive recovery

The initial audit found operations whose effects could outlive their saved state. A mid-import failure could leave copies on disk while the app recorded no successful progress; a retry could then create another suffixed copy. Verification relied on byte counts, and cleanup could trust an earlier lifecycle state after the archive copy had changed.

I changed import to persist an **immutable destination plan before copying**, stage each copy, verify its SHA-256 and checkpoint per-file progress. Canonical photo records retain the imported digest. Retry uses the recorded destinations and refuses silently changed selections, source configuration or backup consent.

Cleanup now rechecks the complete selected JPEG/RAW set against the recorded import digest before deleting any source. A missing or altered destination retains the source. Partial deletion is recorded per member so the remaining work can resume. Main-machine and backup gates apply inside the service as well as in the interface. Historical archive-source cleanup has a narrower recorded-origin rule described below.

Moves and migration also record recoverable intent before mutation. Collision names are resolved consistently in structural manifests and logs; path rewriting targets typed fields rather than arbitrary text in notes. Same-Trip moves leave the record alone. Canonical identity, titles and human sections survive membership changes. Saved Photo Logs reconcile moved media by canonical identity, including return moves and reused paths.

Meaningful regressions included equal-size corruption, a missing destination, source and destination changed together, a failed second copy, failed manifest writes, RAW-companion failures, occupied destinations, interruption after a move and escaping symlinks. The first nine fault tests failed against the initial code before the fixes. The final safety release passed 225 tests.

These changes improve recovery from the tested failures. They do not certify every filesystem against physical power loss. The archive lock coordinates local Walkfolio operations; it is not a distributed OneDrive lock. [Detailed safety evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-100-reliability-and-completion-report.md).

## Durable records and complete index publication

Canonical editing now preserves unknown fields, notes and independent Walk values. Appending an import reserves manifest stems across extensions, retains existing Walk membership and text, and appends session events. Coordinates and identities survive index deletion and reconstruction at a relocated root.

Index rebuilding publishes a complete staged generation through an atomic pointer. Expected shard hashes expose incomplete synchronisation; a failed replacement leaves the previous generation readable. A full rebuild can repair a damaged pointer. Delayed thumbnail work re-reads current canonical metadata before publishing, so an older job cannot overwrite a later edit.

I tested failed generation writes, corrupt pointers, missing synchronised shards, duplicate canonical paths, locked projection and delayed thumbnail publication. The principle throughout is that an unavailable or incomplete projection must not silently become the durable truth about the archive. [Safety and index evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-100-reliability-and-completion-report.md).

## Travel browsing and deliberate original viewing

Travel catalogue, grids and search now work at a fresh root containing only the pinned `_index` and prepared thumbnails. They do not require original directories, canonical manifests or original-folder enumeration. Historical folder rows, stable photo identities, dimensions, RAW companions and crop families are projected into the index so they remain useful away from the main archive.

Routine Travel browsing avoids original preheat and missing-thumbnail generation. A prepared preview displays; a missing preview stays a placeholder. **Full original viewing requires an explicit action for the selected path**, including when that original is already resident. Grants are held in memory and revoked by authority changes. A cancelled, timed-out or late FileProvider/decode result cannot grant access to a different context.

Tests use fresh roots with absent originals and a file-manager spy that refuses original enumeration. They cover linked paths, case-sensitive grouping, crop relationships, resident consent, stalled transports, cancellation and late completions after policy reset. These are enforcement tests; actual OneDrive download and eviction behaviour still needs acceptance on the real provider. [Index-only Travel evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-101-index-only-travel-report.md), [explicit viewing evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-102-archive-map-report.md).

## Map, locations and Trip labels

The archive-wide Map uses the same year, kind and search projection as Timeline and Contact Sheet. It supplies indexed Walk pins, native clustering and lists for located/unlocated Walks and historical folders. A cluster zooms; a Walk opens its photo grid.

Location handling preserves the distinction between raw camera GPS and an assigned location. Photo overrides, Walk pins and GPS retain their fallback rules; saved Walk pins control archive placement. Spherical centroids handle the antimeridian and reject ambiguous antipodal groups. Crop derivatives inherit their originals and do not add extra centroid weight.

Contextual editing targets the canonical Walk when no photos are selected, or the exact selected originals when photos are selected. Shared assignments have a stable identity; changing one member detaches that member. Recoverable multi-file saves preserve notes and unknown fields, reject conflicting text and survive root relocation. Pending operations block overlapping moves and index publication.

Trip label overrides preserve identity, human sections and ordered membership. Default-month Trips receive canonical records just as named Trips do. Appends, moves and mixed legacy/modern migration update the appropriate members without discarding the label. Travel can save targeted tiny canonical metadata while leaving the shared index unchanged; other index-only views need Main to publish the updated index.

Tests cover invalid coordinate pairs, pin precedence, clear/fallback, raw-GPS preservation, interrupted shared saves, stale targets, moved members, occupied canonical destinations and fresh index-only reconstruction. Native Map rendering and gestures remain open; retained Map action authority also remains a follow-up in the frozen build. [Map evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-102-archive-map-report.md), [contextual locations](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-103-contextual-locations-report.md), [Trip labels and migration](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-105-trip-location-labels-report.md).

## Historical folders and honest date provenance

Historical Source opening now starts new material **kept**, and reopening retains saved exclusions, RAW choices and date preference for unchanged files. Title and date hints feed ordinary Walk grouping and Trip planning. Camera dates remain the default when valid; explicit folder-date preference retains the camera evidence and any conflict. Day/month/year precision is recorded, and date-only evidence does not invent an exact capture time.

The confirmed Copy plan is saved before the first copy. After a failure, opening the saved Photo Log presents the same destinations in a locked recovery sheet. The log cannot be edited, cropped, replaced or deleted in ways that would invalidate that plan while recovery is pending. A separate Source remains available.

Recognition of prior copies uses SHA-256, including after corrected dates or archive relocation. Recognition alone does not permit cleanup. Historical archive-source cleanup requires the explicit recorded source root, its own completed import to a separate destination, backup/Main gates and verification of the whole original/RAW batch. Uncopied material and source directories remain.

The strongest workflow regression runs actual AppState Copy, fails the second file, constructs a new AppState with the persisted store, opens the log and finishes the same plan. Other tests cover missing/conflicting dates, changed RAW companions, disconnected archives, hardlink aliases and canonical material under a historical root. A real copied old folder and reviewed date/Trip confirmation remain acceptance work. [Historical triage evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-104-historical-triage-report.md).

## Local descriptions and recoverable batches

Photo descriptions, Walk summaries and Trip overviews are explicit actions. They do not start while you triage. Settings expose the LM Studio endpoint, model discovery and an explicit selected model. Travel input comes from prepared thumbnails; missing or linked inputs fail rather than silently hydrating an original.

Generated descriptions occupy separate owned sections and retain immutable revisions, actual/requested model, generation date, endpoint, prompt version, target identity, input digest and child coverage. Human notes remain independent. A successful regeneration replaces the active result; a failed one preserves the old active result. Search uses active text.

The serial queue records batch intent, saves completed responses before canonical publication and validates inputs again before saving. Failed child refreshes cannot produce newly dated parent summaries from stale child evidence. Successful-save/failed-receipt recovery avoids another model call. Cancel, explicit Resume and whole-batch Discard have durable ownership, including interrupted acknowledgements and partially written receipts.

Later command work captured target and model configuration before asynchronous scheduling, rejected root/model round trips, and guarded retained Settings/queue controls. Tests cover malformed responses, changed notes/identity/bytes, response-ready restart, cancellation, dependency failure and recovery without duplicate publication.

The recorded local model probe found no LM Studio server listening. I did not run a real vision model or assess description quality. Model discovery itself would not prove vision capability. [Description implementation evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-106-local-descriptions-report.md), [later queue and command corrections](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-112-command-layer-and-sidebar-report.md).

## Google Photos delivery and membership

The implementation provides explicit Desktop OAuth sign-in, a reviewed account/destination/count/byte summary and a serial resumable delivery queue. Tokens and transient upload handles use Keychain. Only an explicit confirmed Send starts new delivery; startup and ordinary triage do not send photos.

The queue captures canonical photo identity and verified original bytes. It streams bounded resumable chunks, queries offsets after interruption and retains progress through token/session expiry and quota pauses. Account/client/root/role changes stop further requests. Unknown album-creation outcomes require explicit reconciliation before another album is created.

Remote responses and verified membership are recorded before canonical publication. Local failures can retry receipts without another upload. Account-scoped badges survive rebuild and fresh Travel projection. Manual older-upload marks remain explicitly unverified; clearing them preserves verified receipts. Generated crops and RAW companions are excluded from original delivery coverage. Travel delivery requires a current viewing grant and resident bytes; it does not hydrate.

Later command tests exposed and fixed retained discarded confirmations, stale asynchronous publication, out-of-order review requests and old reviews surviving after delivery. Exact review identity now remains part of authority through these transitions.

All provider execution evidence is injected. **No live Google sign-in or private-photo delivery ran.** The provider's recorded membership is not a remote SHA-256 comparison and cannot establish byte-verified cleanup permission. Real client setup, a disposable test account, album append/interruption/retry and visible membership need live acceptance. [Google delivery evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-107-google-photos-delivery-report.md), [command/review corrections](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-112-command-layer-and-sidebar-report.md).

## Complete app-state backup and restoration

The full-scope audit found that recent decisions could be omitted from export, and a failed restore could leave settings and saved sessions from different snapshots. I fixed the complete backup boundary rather than relying on a successful SQLite operation alone.

Export drains pending decisions from every saved session, preserves independent write failures and refuses corrupt or interrupted reads. Versioned backups retain precise dates and legacy classification. Validation detects duplicate identities and missing internal references without demanding that every historical volume be online.

Restore records the complete before-image before changing either store. Prepared restoration rolls back on failure or reopening; committed restoration survives a failed journal cleanup. Failed rollback retains evidence, gates ordinary writes and exposes Retry Recovery. Empty restoration clears the old session instead of resurrecting it. A RAM fallback cannot claim durable backup success.

Thirty-four new regressions cover immediate two-session export, edit/delete/export, actual SQLite rollback triggers, corrupt/locked reads, failed settings/journal writes, prepared/committed reopen, empty retry and stale editor/task/grant invalidation. Multi-Source membership transfers are atomic. Native export/import file pickers and physical power-loss behaviour remain separate. [Backup recovery evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-108-state-backup-recovery-report.md).

## Archive navigation, search and responsiveness

Subsequent source audits found original usability requirements still missing even after the composed workflow passed. I fixed measured card columns, displayed-year navigation, short-row column intent and selection retained on Back. Open previews the focused photo. Map keyboard selection follows the visible list, and contextual backend actions use that selection.

Catalogue projection is cached independently of selection. Counts, year groups, matching photos and Map data do not regroup every archive photo on each arrow event. Catalogue, filters, search and root changes invalidate the projection.

Search now displays exact matching photos alongside entries. Root-relative paths distinguish duplicate filenames and survive fresh historical UUIDs. Opening a hit selects and scrolls to that photo, clears a hiding review filter and reports a missing hit explicitly. Each accepted catalogue owns a disposable FTS database and a unique search request. Old success/error results cannot replace newer root/query state. Folder loading distinguishes loading, empty, failed/Retry and missing-hit states. Refresh maps Preview/Compare selections by path and respects a close made while work is suspended.

Prepared covers now load off the SwiftUI body on a dedicated bounded queue: three physical decoders, 128 distinct pending keys, and a cache capped at 128 decoded buffers and 64 MiB using actual padded buffer bytes. Visible requests have priority; shared subscriptions and cancellation retain correct worker accounting. Covers are resident prepared JPEGs of at most 512 pixels. Linked/dataless/unsafe files remain placeholders; the worker applies the narrow no-materialisation policy. Full Preview decoding is independent.

Tests include 5,100 search matches, reversed query/root/folder completions, real SQLite transaction failure, exact-hit Travel opening with absent originals, corrupt covers, real JPEG decoding, noncooperative cancelled workers, full-queue admission and hard cache limits. These establish bounded fixture behaviour, not real native scrolling comfort. [Navigation](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-109-archive-navigation-report.md), [search and folder recovery](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-110-archive-search-and-folder-feedback-report.md), [cover loading](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-111-archive-cover-loading-report.md).

## Commands, shortcuts, focus and captured targets

The final and largest build addressed mouse/keyboard agreement throughout the app. The audit found duplicate focus/grouping chords, reserved-key conflicts, hard-coded help, broad modifier matching and focus being reclaimed during redraw. The implemented foundation gives commands stable identities, availability reasons, effective persisted bindings and a shared execution route.

**Cmd-Shift-P** opens the command palette, **Cmd-K** opens contextual commands and **Cmd-/** displays generated shortcuts. Settings exposes assignment/reset/unbound states, rejects collisions and reserved misuse, and surfaces persistence failures. Native menus and key handlers use the same effective bindings. Ordinary macOS text movement, Select All, Copy and IME composition retain their behaviour.

Focus is owned by the invoking window and actual containing surface. Queued requests validate the registered lease, native target, ancestry, visibility, modal boundary and current context before focusing. Ordinary redraw does not steal focus. Tests use real hidden NSTextView/NSTextField editors, shared field editors and NSWindow event paths, including two windows and closed-window startup.

Mouse controls retain the target they displayed. If a row shows photo A, selecting B elsewhere must not make that row mutate B. Controls reject removed/replaced targets, root or workspace round trips, hidden panes, changed drafts and replaced containers. Selection-only changes preserve valid displayed targets. This rule was implemented for Review photo/group/crop controls, Preview/Compare, location and Trip editors, description/Google queues, copy-plan forms and most workflow controls.

Crop completion can retain a successfully saved crop without replacing the photo currently being viewed or its status. Queued canvas updates cannot restore an old crop after Cancel/Fit or disposal. Copy waits for active crop work, imported members remain locked and failed saves retain drafts or recoverable output.

Source and folder navigation now uses snapshot-issued tree and parent context. Native folder Cmd-A selects folders; Cmd-Return and double-click open the displayed folder through the registered route. Sidebar arrows and folder-to-Review focus are exercised through actual hidden production containers. Old native Lists cannot triage a new source before SwiftUI redraw.

Native menu adoption preserves standard menu ownership, delegates and automatic enabling. Menu tracking retains the original registered window/responder/selection through activation. Replaced/closed owners reject old actions. Detached NSMenu tests verify targets, keys and validation; they do not certify the real SwiftUI menu-bar bootstrap.

These changes added **211 tests after 0.7.15**: 160 command-file functions, 14 Google callback functions, 13 description functions and 24 image command/completion functions. The whole inventory was still unfinished when you stopped development. [Full command and captured-control evidence](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-112-command-layer-and-sidebar-report.md).

## How I established the test evidence

I used the existing Swift package, Swift Testing and AppKit/SwiftUI fixtures without adding a new app framework or dependency. Main-actor/native tests ran serially. Temporary archives, synthetic JPEGs, injected file/provider failures and delayed callbacks made interruptions and races repeatable without touching your live archive.

The tests check workflow invariants: retained sources after corrupt-copy refusal, one recorded destination after retry, canonical text preserved across reconstruction, stale asynchronous results refused and the exact displayed target acted upon. They also cover positive fresh-control actions so guards do not merely disable everything.

For several defect classes I kept pre-fix failure logs, then deliberately removed a repaired guard and ran the relevant tests again. Working source bytes were restored and checked before the final full suite. Examples include native menu authority, inherited bindings, hierarchy ownership, Review focus and source/folder capture. In the final source/folder replay, removing the leaf/ancestor validity guard failed four named functions with twelve assertions. Earlier raw counters accidentally included the run summary as a function; the archived counts were corrected to unique named tests.

Some intermediate failures were fixture or tool mistakes: a burst fixture initially lacked its members, an explicit hidden layout required another run-loop turn for queued focus, and an installation verifier initially assumed an obsolete Swift output path. These were corrected without bypassing checks. They are not reported as product defects or runtime acceptance.

The final recorded full suite is **658 tests / two suites / 95.350 seconds**. Source and tests were unchanged during packaging and this report; I did not repeat the full suite solely for documentation. The [durable final log](/Users/dominiklukes/gitrepos/01_reading-research/_LEARNINGLOG/workflows/recoverable-photo-archive-operations/sources/source-folder-navigation/logs/walkfolio-source-navigation-final-full.log) and per-slice source/review/fault evidence are archived with manifests. Exact synthetic thumbnail-cache UUID substitutions in selected archived logs retain original hashes and line provenance; the raw temporary logs were not rewritten. Normal secret scans passed without rule exceptions.

## Performance measurements and their limits

| Fixture measurement | Recorded result | What it supports |
|---|---|---|
| Deterministic import of 128 files × 256 KiB. | 0.275 seconds; 306,465 recovery bytes. | Bounded local copy/recovery bookkeeping. |
| Actual AppState navigation over 50,000 photos and 100 Walks. | Projection reused across 1,000 arrow calls. | Selection does not repeatedly rebuild the catalogue/Map projection. |
| Shared target index with 30,000 photos. | 500 checks in about 25 ms. | Captured membership validation is bounded in this fixture. |
| Production Review, 30,000 photos, 100 mounted rows, 100 key events. | Initial full-menu refresh: 27.315 seconds; corrected: 0.492 seconds with one selected, 0.483 seconds with all selected. | The per-key menu-refresh defect is substantially reduced while display/action validation remains. |

These are synthetic local measurements. They are not end-to-end OneDrive throughput, large real-image decoding timings or proof of native responsiveness on your photographic archive. Hidden layout measurements at narrow pane sizes established fitting/height behaviour but did not establish visual polish; some native controls were omitted by offscreen capture/traversal.

## Astra and Claude Opus consultation

Astra repeatedly reviewed source and specifications read-only. Its concrete findings were converted into targeted failure cases and fixes, including canonical context, late queue publication, crop/focus lifetime, full cover-queue admission, padded-buffer accounting, menu tracking and inherited commands. I performed the code changes and test execution. A clear final review applies to its reviewed slice, not to every unreviewed control or real provider.

The earlier Claude Code consultation reported model **`claude-opus-5-5`**. It received only a bounded packet describing public source at commit `9da3eb1`, with no private archive, user history or credentials. It used no tools and did not inspect the checkout itself. Its advice supported durable forward recovery, staged verified copies, atomic complete index generations and schema-aware rewriting. I treated its other suggestions as proposals, rather than assuming all were implemented.

The [public-source packet](/Users/dominiklukes/gitrepos/01_reading-research/_LEARNINGLOG/workflows/recoverable-photo-archive-operations/sources/walkfolio-opus-public-packet.md) and [verbatim response/metadata](/Users/dominiklukes/gitrepos/01_reading-research/_LEARNINGLOG/workflows/recoverable-photo-archive-operations/sources/walkfolio-opus-review.json) are retained. Consultation is design/review input; passing primary-run tests and build checks provide the execution evidence.

## The installed review build

When you asked to stop, I froze implementation at the 658-test source and paused the persistent development goal. You then closed the running 0.7.15 app and explicitly authorised installation. I packaged the existing source with the repository script, using its debug Swift build and ad-hoc signing, and replaced the exact installed bundle rather than merging files into it.

The following checks passed:

- Info.plist identifies **0.7.16 / build 152** with the expected app identity and feature marker.
- Built and installed bundles pass `codesign --verify --deep --strict --verbose=2`, reporting “valid on disk” and satisfaction of the Designated Requirement.
- The installed executable equals the packaged executable; removing signing envelopes from temporary compiled/packaged copies gives equal code bodies.
- Packaged release metadata equals the source release file; source/tests remained unchanged after the complete suite.

The installed executable SHA-256 is `660d59dad367c835424878acfe6a01de9cf377540fe607c4c40d323a65ed9a08`. The unsigned code-body SHA-256 is `ddca1de3e9381493734e03ea571694c6ba9662558974612c28a9dbdf4292daa5`. The prior real 0.7.15 bundle was retained at `/private/tmp/walkfolio-before-review-20261003T045747Z/Walkfolio.app`; that temporary backup is not a durable archive backup.

I left the app closed. This verifies packaging and installation, not runtime liveness or visual acceptance. Ad-hoc signing is not a notarised distribution release. The [freeze and installation receipt](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-112-command-layer-and-sidebar-report.md) records the details.

## Known unfinished implementation

The remaining issues were identified before the freeze and are recorded for a later explicit resumption. I did not quietly finish them after you asked to stop.

1. **Retained Archive actions need exact displayed authority.** Timeline/contact/search entry callbacks can select a captured ID and then invoke global Open/Organise. If selection rejects an obsolete ID, the global action can use another current selection. Trip Walk cards, search photos and Map routes need the same captured-context treatment.
2. **Old map annotations can borrow a newer callback.** Updating the native coordinator callback while retaining an old annotation can give an old event new authority, including an identical-value root/filter round trip. An annotation must carry its issued context or captured action and be invalidated when that context changes.
3. **Search selection precedes focus in the corrected design.** Existing search callbacks request focus before changing selection, which can invalidate the queued focus fingerprint. The future fix needs a real hidden search-card/arrow test.
4. **Two Log/inspector links remain outside the completed route.** The Inspector destination link can display a captured path but open the current session's destination. Open Existing Log from a collision needs registered discovery and exact editor/owning-log authority.

Astra's final Archive advice was preserved without implementation. The follow-up design uses a snapshot-issued, selection-independent display revision covering catalogue/filter/search/view/navigation/root/workspace changes, including ABA round trips. Validation must use the displayed projection, not the complete catalogue. Selection-only changes should keep a still-displayed A usable after B becomes selected.

Future regressions should retain A's action after it disappears while B is selected, repeat root/filter/catalogue/navigation round trips, deliver an old map annotation after context replacement and exercise old native panes before redraw. Fresh controls should succeed; stale controls must not substitute B. These are planned tests, not tests counted in the 658.

## Acceptance still needed in real use

| Acceptance | Why it remains open |
|---|---|
| Native commands, menus, selection, text editing, layout and mouse gestures. | Hidden production containers and detached menus cannot establish the actual menu-bar bootstrap or comfortable headed use. |
| A copied real old folder and verified migration dry run. | Synthetic recovery and preservation tests do not replace reviewing real dates, Trip proposals, layout variation and gated cleanup on a backed-up copy. |
| Actual OneDrive index/thumb synchronisation, viewing, preparation and eviction. | FileProvider spies and filesystem guards do not establish real provider timing, allocated-size behaviour or the 15 GB floor in operation. |
| A selected LM Studio vision model and description quality. | The server was unavailable; injected responses test protocol and recovery rather than semantic quality or real model capability. |
| Google Desktop OAuth and a disposable test-account delivery. | Mock bytes, offsets and membership receipts do not establish live account setup, album creation/append/retry or remote results. |
| Native backup export/import and the full photographic-life journey. | Picker interaction and a complete real-copy/native/provider run remain distinct from the integrated fixture. |

The composed automated journey is substantial: camera plus phone produce two same-day Walks in one named Trip; human notes and GPS survive; locations and six dependent descriptions are added; three mock album members are verified; the index is removed/rebuilt; a fresh Travel root browses, searches and maps without originals. Its strength is the integration it exercises. Its limit is that the photos, providers and archives are fixtures.

## Review handoff and pause

I filed a [four-check review request](/Users/dominiklukes/gitrepos/_DTC/photo-diary-triage/2026-10-03-walkfolio-commands-navigation-0.7.16.md) for commands, sidebar/folders, photo decisions and ordinary text editing. An [artificial Source guide](/Users/dominiklukes/gitrepos/_DTC/photo-diary-triage/playground/walkfolio-commands-0.7.16/README.md) supplies eight synthetic gradient JPEGs in camera/phone folders, with copied-file hashes. The review does not require copying to your live archive or using provider accounts. No watcher runs.

The global task is awaiting your review, the cold handoff records the remaining work and the persistent goal is paused. Development will resume only if you explicitly ask. The complete 1.0 scope remains unaccepted; this report and the installed checkpoint preserve the progress without claiming that every aim has been achieved.

## Source records

This report consolidates the release-specific records already linked above. They retain the finer file lists, pre-fix logs, follow-up discoveries and test limitations. The principal current records are:

- The [development goals](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/planning/development-plan-walkfolio-reliability.md) explain the intended whole workflow.
- The [requirements audit](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/planning/audit-walkfolio-completion-requirements.md) traces the original work packages and remaining acceptance.
- The [command/control specification](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/backlog/PDT-2026-10-02-112-command-layer-and-sidebar.md) and [implementation report](/Volumes/BigData/gitrepos/06_apps-utilities/01_desktop-apps/photo-diary-triage/changelog/changelog/PDT-2026-10-02-112-command-layer-and-sidebar-report.md) preserve the frozen inventory and installation receipt.
- The [archived recovery evidence](/Users/dominiklukes/gitrepos/01_reading-research/_LEARNINGLOG/workflows/recoverable-photo-archive-operations/README.md) routes source snapshots, public-source consultation, regression logs, manifests and reusable findings.

This is a documentation-only consolidation. It does not change the installed app, its release metadata, the frozen source or the paused development goal.
