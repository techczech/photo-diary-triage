# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Locked inputs for this prototype

- The mockup combines the selected Timeline and Contact Sheet concepts as two views over
  one Archive.
- Timeline is the default; Contact Sheet is the remembered compact alternative.
- Selection, year position, and search query survive view changes.
- "Archive" and individual years are not separate destinations. A year filters the
  same Timeline or Contact Sheet, and the complete Archive groups entries by year.
- The Archive contains recognised Trips and unorganised folders. A physical folder is not a
  Trip or Walk unless its manifests say so.
- Historical year folders may contain arbitrary nesting. Do not infer months from folder
  depth, and do not hard-code 2016 as a structural boundary.
- An unorganised folder opens to its photos without moving or renaming anything. Organisation
  is a separate explicit action.
- Use only local photographs selected from Dominik's Archive. Do not use generated or
  externally hosted cover images.
- This prototype is a design artefact. It must not be treated as production Walkfolio code.
