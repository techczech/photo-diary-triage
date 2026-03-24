# Test Agents

Use this file for verification work under `Tests/PhotoDiaryTriageTests/`.

## Required Coverage Priorities

- Selection correctness for mouse and keyboard.
- Review shortcut scope and focus gating.
- Grid navigation based on actual rendered geometry.
- Preview and compare state transitions.
- Persistence, recovery, import verification, and cleanup gating.

## Test Style

- Prefer deterministic fixtures and temp directories.
- Verify behavior against [DESIGN.md](/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/DESIGN.md), not only against implementation details.
- Add regression coverage before changing interaction semantics.
- Keep tests centered on real review workflows, not only isolated helpers.

## Manual Verification Expectations

- Record whether grid layout, selection, preview, compare, and keyboard flows were exercised manually for each usability slice.
