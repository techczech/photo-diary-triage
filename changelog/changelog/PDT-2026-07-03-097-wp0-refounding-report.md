# PDT-2026-07-03-097 WP0 — Walkfolio re-founding (report)

item_id: PDT-2026-07-03-097
shipped_release_version: 0.3.0 (build 129)
shipped_feature_slug: walkfolio-refounding

## Summary of what changed

WP0 of the approved Walkfolio 1.0 completion plan: documentation re-founding, app rename,
and tracking normalization. No behavioral app changes beyond the display name.

- **PRD.md**: full rewrite to the Walkfolio identity (photo archive manager with a strong
  triage component) and the Walk/Trip/Triage domain model; goals now include timeline/map/
  search browsing, Archive Index, LM Studio descriptions, Google Photos push, historical
  processing; Non-Goals reflect the -097 OUT list (no editing/straighten, no GPX, semantic
  search later).
- **DESIGN.md**: retitled Walkfolio; references CONTEXT.md as canonical domain language;
  Navigation rules now sanction the Timeline of Trips as the primary archive browse surface,
  plus Map mode and Search as index-backed lenses (all terminating in the grid, rule 1
  preserved); group-browsing wording updated to Trips/Walks; travel-mode no-implicit-download
  rule added (ADR 0002). All non-negotiable rules otherwise unchanged.
- **App rename**: window title "Walkfolio" (PhotoDiaryTriageApp.swift); bundle builds as
  dist/Walkfolio.app with CFBundleName/CFBundleDisplayName "Walkfolio". Executable name and
  bundle identifier (local.photo-diary-triage) unchanged per spec. Old dist bundle removed.
- **Tracking normalization** (backlog.jsonl, append-only): 92 items whose latest status was
  `awaiting_user_review` (accepted implicitly through months of daily use) normalized to
  `approved_done`; crop-repair audit items -076 and -079 marked
  `superseded_by_completion_plan` (crop rework shipped 0.2.44–0.2.48). PDT-2026-05-30-096
  (map render fix) deliberately left `awaiting_user_review` — it is the standing test gate.

## Files changed

- PRD.md, DESIGN.md (rewrites/updates)
- Sources/PhotoDiaryTriage/PhotoDiaryTriageApp.swift (window title)
- scripts/build_app_bundle.sh (bundle name, display name)
- APP_RELEASE.env (0.3.0 / 129 / walkfolio-refounding)
- changelog/backlog.jsonl (+94 normalization events), this report, changelog.jsonl

## Verification performed

- `swift build` passes; app bundle built and installed to /Applications/Walkfolio.app;
  Info.plist reports 0.3.0.
- backlog.jsonl re-parsed after normalization: only -096 remains `awaiting_user_review`;
  -097 is `approved_for_implementation`; all lines valid JSON.
- The old /Applications/PhotoDiaryTriage.app (0.2.51) left in place until the user confirms
  0.3.0, then it should be deleted.

## Known gaps / follow-ups

- Walk/Trip display-label configurability in Settings ships with WP1 (when Walk/Trip first
  appear as UI strings); sequencing only, not a descope.
- The -096 map test can be performed in 0.3.0 (identical map code); confirming the map panel
  in 0.3.0 closes the gate.
- Repo slug, bundle id, and code module names intentionally keep photo-diary-triage /
  PhotoDiaryTriage; any future rename is tracked in the global backlog, not this plan.

## Test handoff

**Please test APP_VERSION 0.3.0 (build 129), /Applications/Walkfolio.app.** Intended
user-visible behavior in this version: the app launches as "Walkfolio" (Dock, window title);
everything else behaves exactly as 0.2.51, including the map panel fix — toggling Map in
review shows a visible, correctly-pinned map (testing it here also closes item -096).
