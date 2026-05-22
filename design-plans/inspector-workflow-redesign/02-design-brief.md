# Inspector Workflow Redesign Brief

## Purpose And Audience

- The inspector helps a keyboard-first photo triage user understand the current state of a photo log and take the next safe action.
- The key user need is confidence: know what happened, where the copied files are, and what is safe to do next.

## Primary User Task

- After copying a log, open the archive folder, inspect the copied photos, confirm backup, then decide whether to clean the SSD source.

## Visual Hierarchy

- Put the workflow panel first.
- Show the archive folder path as a link-style row inside the workflow panel.
- Put primary actions directly under the workflow state.
- Put current log facts second.
- Collapse photo-log library and storage/source details.

## macOS Direction

- Use native GroupBox surfaces, small system icons, compact spacing, link-style buttons, and Finder language.
- Keep dense but orderly layout.
- Avoid a landing-page or marketing look.
- Avoid huge cards, oversized typography, and decorative colour.

## Required States

- Ready to copy.
- Copying.
- Copied and waiting for backup confirmation.
- Backup confirmed and ready for source cleanup.
- Copy failed.

## Cognitive Walkthrough

- Step 1: User sees workflow state at the top.
- Step 2: User notices a clickable archive folder path.
- Step 3: User opens the folder and understands it is for inspection, not confirmation.
- Step 4: User confirms backup only after checking the archive.
- Step 5: User sees cleanup as a separate final action.

## Avoid

- Do not bury the archive path in a metadata table.
- Do not put source workspace controls above the current task.
- Do not show a long photo-log library in the first viewport.
- Do not make backup confirmation look automatic.
