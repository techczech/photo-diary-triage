# PDT-2026-05-25-072: Laptop screen fit

## User request summary

- Screenshot shows app wider than laptop screen.
- Find root cause.
- Suggest fix.

## Constraints

- Investigation first; no shipped code change yet.
- Preserve inspector/sidebar workflows.
- Preserve keyboard-driven triage.
- Keep grid/archive browsing responsive and non-overlapping.
- Respect SSD-first selective-import workflow.

## Implementation intent

- Inspect root window layout, split panes, inspector, sidebars, toolbar, and fixed frame constraints.
- Identify exact width constraints or content that force window overflow.
- Recommend a small fix path before implementation.

## Test conditions

- App fits inside laptop logical viewport shown in screenshot.
- Sidebars and inspector do not clip at typical laptop widths.
- Archive, camera triage, photo logs, and archive triage remain usable.
- Toolbar actions remain reachable without horizontal overflow.

## Success criteria

- Cause named with file and line evidence.
- Suggested fix names target files and user-visible behavior.
- If implementation follows, release target and changelog records updated.

## Current status

- implemented pending user review

## Findings

- Screenshot file is `2560x1664` pixels with `@2x` name, so visible laptop viewport is about `1280x832` points.
- App root requires `1380` point minimum width in `Sources/PhotoDiaryTriage/PhotoDiaryTriageApp.swift`.
- Main layout also reserves three wide panes:
  - sidebar min `260`
  - detail min `720` plus horizontal padding
  - inspector min `300`
- Archive header adds more pressure through a fixed `560` point segmented mode picker plus trailing buttons.
- Result: current `0.2.29` layout cannot fully fit a 1280-point-wide laptop screen with sidebar and inspector visible.

## Suggested fix

- Lower root window minimum below laptop width; use `defaultSize` for launch size instead of a large content minimum.
- Make pane minimums fit the target viewport:
  - sidebar min around `220-240`
  - detail min around `560-600`
  - inspector min around `260-280`
- Make `HeaderPaneView` responsive:
  - replace fixed `560` picker width with flexible min/ideal/max sizing
  - collapse trailing header actions into icon/menu form at narrow widths
- Consider auto-hiding inspector first below about `1180-1200` points, while keeping toolbar/keyboard toggle available.

## Target release version

- `0.2.30` if implemented.

## Target feature slug

- `laptop-screen-fit`
