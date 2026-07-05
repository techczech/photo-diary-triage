# PDT-2026-07-03-097 mode switcher clarity (report)

item_id: PDT-2026-07-03-097
shipped_release_version: 0.5.1 (build 134)
shipped_feature_slug: mode-switcher-clarity

## Summary of what changed

User feedback on 0.5.0: the toolbar mode switcher showed four unlabeled icons (macOS
toolbar segmented controls drop Label titles), and the four modes themselves were unclear.
User decision (2026-07-05): three modes with text labels.

- Mode switcher segments are now text: **Archive · Triage · Photo Logs**.
- **Archive Triage is folded into Triage** — consistent with the domain model (historical
  processing is ordinary Triage on an old folder). `.archiveTriage` remains a hidden legacy
  enum case (not in displayOrder; it was read-only in recent builds and is not persisted,
  so nothing is lost).
- "Open in Finder" in the toolbar shows title + icon instead of a bare folder glyph.
- planning/codex-implementation-plan.md Release H updated: historical processing lives
  inside Triage mode, not a fourth mode.

## Files changed

- Sources/PhotoDiaryTriage/Models.swift (WorkspaceMode titles + displayOrder)
- Sources/PhotoDiaryTriage/ContentViewBrowserSections.swift (text segments; labeled button)
- planning/codex-implementation-plan.md, APP_RELEASE.env

## Verification performed

- swift build passes; full swift test — 168 tests green.
- 0.5.1 bundled and installed to /Applications/Walkfolio.app.

## Known gaps / follow-ups

- The workspace explanation ("what do I do where") also lives in the header caption text;
  the fuller onboarding clarity lands with WP3's Timeline redesign.

## Test handoff

**Please test APP_VERSION 0.5.1 (build 134), /Applications/Walkfolio.app.** The toolbar
should show three labeled segments — Archive, Triage, Photo Logs — plus a labeled "Open in
Finder" button. The 0.5.0 Walk/Trip test asks still stand (same-day split; cancel-then-mark;
move Walk to Trip).
