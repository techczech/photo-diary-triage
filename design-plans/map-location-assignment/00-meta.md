# Map + location assignment — meta

item_id: PDT-2026-05-30-096
status: in_progress (C.1 shipped 0.2.49; C.2 shipped 0.2.50; C.2 render fix 0.2.51)
owner_decision: panel-in-browsing; assign at walk/day/cluster/photo; show GPS + assign

## Purpose

Detailed UX plan + cognitive walkthrough for the map/location feature, authored BEFORE
asking the user to test, after the user reported the map panel rendered nothing.

## Files

- 01-design-brief.md — placement, states, interactions, persistence, edge cases.
- 02-cognitive-walkthrough.md — step-by-step user-goal walkthrough; issues found + status.

## Hard constraints

- Grid stays the primary review surface (DESIGN.md §1); map is an optional inline panel.
- Most of the user's photos have NO embedded GPS, so manual assignment is the core flow,
  not GPS plotting.
- Author cannot GUI-test (Command Line Tools only; no XCTest, no screenshots). Therefore:
  reason through each state on paper, prefer deterministic/forced layouts over intrinsic
  sizing, and provide a non-gesture fallback for every map gesture.
