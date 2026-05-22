# Cognitive Walkthrough

Method reference: NN/g, "Evaluate Interface Learnability with Cognitive Walkthroughs".

## Task

- User has copied a photo log and wants to confirm the copied photos before backup confirmation and source cleanup.

## Step 1: Understand Current State

- Right result: User needs to know whether the log is ready to copy, copied, waiting for backup, or ready for cleanup.
- Notice action: Workflow panel is first in the inspector.
- Association: Title, state badge, and stage list use copy/review/backup/cleanup language.
- Progress feedback: State line changes from copying to copied, backup confirmed, or cleanup ready.
- Result: Pass.

## Step 2: Open Copied Folder

- Right result: User wants to see the copied photos on disk.
- Notice action: The archive path is a link-style row labelled "Copied archive folder".
- Association: Folder icon, path text, and Finder/open icon connect the action to opening the copied folder.
- Progress feedback: The app status message reports the folder was opened or unavailable.
- Result: Pass.

## Step 3: Confirm Backup

- Right result: User confirms backup only after inspecting the copied photos.
- Notice action: Confirm Backup appears beside the archive-folder action only when it is valid.
- Association: Wording keeps "open folder" and "confirm backup" separate.
- Progress feedback: Workflow state changes to cleanup-ready after confirmation.
- Result: Pass.

## Step 4: Clean Source SSD

- Right result: User removes copied source files only after backup confirmation.
- Notice action: Clean Source SSD appears as a separate final action.
- Association: The stage list shows cleanup after backup, and the workflow state says when cleanup is ready.
- Progress feedback: Cleanup status message reports that verified imported files were removed.
- Result: Pass, with existing destructive-action confirmation still a follow-up risk outside this redesign.
