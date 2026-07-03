# Walkfolio Design Governance

## Purpose

This document is the non-negotiable UX and product-design contract for Walkfolio (a photo walk diary & archive manager for Mac; working repo name: photo-diary-triage). It exists to prevent ad hoc design drift and to ensure that future implementation work is reviewed against explicit design rules before code is changed.

Domain language (Walk, Trip, Triage, Archive Index, …) is defined in [CONTEXT.md](./CONTEXT.md) and is canonical in code and manifests; only UI display labels for Walk/Trip are user-configurable. Structural decisions are recorded in [docs/adr/](./docs/adr/).

This document outranks incidental implementation choices. If the current app behavior conflicts with this document, the document is authoritative.

## Change Control

### Approval Rule

- No design change may be implemented without explicit user approval first.
- A design change includes interaction model changes, layout changes, selection model changes, shortcut changes, navigation changes, modal behavior changes, and workflow changes.
- If implementation reveals ambiguity, stop and ask before changing design behavior.

### No Assumptions Rule

- Do not make assumptions about desired UX behavior.
- If unclear, research relevant best practices first.
- Present the design recommendation clearly before implementation.

### Verification Rule

- Do not declare design work complete without checking that the implemented behavior matches this document.
- “Do not be lazy and just do something” means incomplete, unverified, or opportunistic UX changes are unacceptable.

## Non-Negotiable Product Rules

### 1. Grid-First Photo Review

- The final content view for photos must always fundamentally be a grid.
- A list view may exist as an optional secondary view, but grid is the default and primary review mode.
- Hierarchical browsing may use sidebar, outline, or list navigation.
- Opening any terminal photo-content node must land in a grid of photos, not a list-only final state.

### 2. Keyboard And UI Parity

- Every frequent action must have visible UI.
- Every keyboard shortcut must have a corresponding visible UI element.
- Every frequent UI action must expose a keyboard shortcut.
- No important workflow may exist only as a keyboard shortcut.
- No important workflow may exist only as a hidden UI gesture.

### 3. Single-Letter Shortcut Scope

- Frequent review actions may use unmodified single-letter shortcuts such as `I` and `D`.
- These shortcuts are allowed only when the photo review grid has explicit focus.
- They must never fire while typing in text fields, settings fields, sheets, dialogs, or other non-review contexts.
- Outside review focus, standard macOS behavior wins.

### 4. Popup And Modal Behavior

- Every popup, sheet, overlay, and modal must be closable.
- Every transient surface must have a visible close affordance.
- Keyboard dismissal must be supported where appropriate and platform-consistent.
- No modal or overlay may trap the user without an obvious exit path.

### 5. Settings, Memory, And Saved State

- Settings must be persistent across launches.
- Archive root and related workflow preferences must always be saved and restored.
- Session state must persist across launches.
- Selection state, import decisions, and recovery state must persist across launches where technically feasible and safe.
- The app must provide manual export/import backup UI for app state.
- “Memory” in this product means durable saved settings, sessions, decisions, and backupable app state, not implicit AI memory.

### 6. Launch Model

- The intended product is a standard bundled macOS `.app`.
- The user should be able to open it from Finder, Dock, Spotlight, or the Applications folder like any normal app.
- Terminal-based launch is acceptable only as a development convenience.
- Terminal-based launch must never be treated as the intended end-user workflow.

### 7. Robustness

- Selection must be correct, predictable, and testable.
- The design must prioritize safe, reversible workflows.
- State recovery must be explicit and reliable.
- Critical actions must be visible, understandable, and verifiable.

## UX Architecture Rules

### Navigation

- Sidebar or outline navigation is allowed and expected for hierarchy.
- Date/group/folder browsing may use list or outline structures.
- Final photo browsing must default to a grid.
- If list view exists for photos, it must be secondary and explicitly chosen.
- The primary Archive browse surface is the Timeline of Trips (newest first: cover, title,
  dates, location, counts) → Trip → Walks → photo grid. The raw folder drill-down is retired
  as a UI (folders remain on disk).
- Map mode (all located Walks as clustered pins) and Search (filename + AI description FTS)
  are sanctioned alternative lenses over the same Archive Index. Both terminate in the photo
  grid, preserving rule 1.
- Archive browsing, search, and map must function from the Archive Index alone — they may
  not require photo bytes, and in travel mode they must never trigger implicit downloads
  (ADR 0002).

### Focus Model

- The app must have an explicit review-focus model.
- Single-key shortcuts only fire inside review focus.
- Text-entry focus must always preserve normal typing behavior.
- macOS-standard window and application shortcuts must continue to work.

### Selection Model

- Selection behavior must be documented and implemented explicitly.
- Click, Shift-click, Command-click, keyboard movement, and import marking must be defined and testable.
- Import marking must be distinct from mere selection unless explicitly approved otherwise.
- Selection behavior must feel robust and unsurprising.

### Group Browsing

- Years, Trips, Walks, and synthetic groups (bursts, time clusters) may behave like folders.
- Opening a group must result in a grid of photos at the terminal content level.
- Groups may be represented in navigation as folders, but they may not replace the grid as the primary review surface.

## Research Expectations

Future design recommendations should be informed by:

- macOS selection and keyboard focus conventions
- photo-browser grid behavior and review ergonomics
- dialog and sheet dismissal behavior
- command discoverability and shortcut clarity
- persistence, recovery, and backup UX

When proposing a design change, cite the principle or platform convention being followed.

## Implementation Guardrails

- Before making any design-affecting code change, confirm it is allowed by this document.
- If it is not clearly allowed, ask for approval first.
- PRD and agent guidance must stay aligned with this document.
- Tests for keyboard behavior, selection, persistence, popup dismissal, and review-grid behavior should be treated as required, not optional.

## Acceptance Checklist

- Final photo content defaults to grid.
- Frequent actions have both UI and shortcuts.
- Single-letter shortcuts only work in focused review mode.
- Typing in fields never triggers review commands.
- Popups and sheets are always closable.
- Settings and sessions persist across launches.
- Backup export/import has dedicated UI.
- The intended product launch model is a standard macOS `.app`.
- No design change proceeds without explicit approval.
