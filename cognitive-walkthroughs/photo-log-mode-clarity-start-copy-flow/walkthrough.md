---
task: "Move from source inbox decisions to a photo log and copy flow without recopying already archived photos"
task_source: prompt
persona: "New user with no prior exposure to PhotoDiaryTriage"
artefact: "PhotoDiaryTriage 0.2.25 local macOS app"
artefact_path: "/Volumes/BigData/gitrepos/14_apps-and-utilities/photo-diary-triage/dist/PhotoDiaryTriage.app"
date: 2026-05-23
steps_total: 6
steps_failed: 0
links:
  source_request: "User asked to investigate copied/on-disk badge discrepancy and clarify starting vs being in photo-log mode."
---

# Walkthrough - PhotoDiaryTriage 0.2.25 - Photo Log Mode Clarity

## Scenario

A new user opens a source inbox from the SSD. Some photos have already been copied into the archive and are detected from archive manifests. The user wants to decide the remaining photos, create or continue a photo log, copy the S photos, and know what to do next.

## Step 1 - Recognise the current work context

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | The header now names the context as Source Inbox Triage or Active Photo Log. |
| 2 | Will users notice that the correct action is available? | Yes | The segmented mode control stays visible, and the context label sits beside it. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | The header says whether S/C/X decisions stay in the source inbox or belong to the active photo log. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | The next-action line changes when the active session changes from inbox to photo log. |

**Verdict:** Pass.

## Step 2 - Interpret already archived source photos

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | The tile status says Copied rather than leaving the photo looking undecided. |
| 2 | Will users notice that the correct action is available? | Yes | The visible lock notice says S/C/X is locked for archived-on-disk items. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | There is no S/C/X row on copied tiles, so the interface does not invite a new copy decision. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | Attempting a keyboard triage action reports that copied items were left unchanged. |

**Verdict:** Pass.

## Step 3 - Mark uncopied source photos

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | The source inbox next-action text says to use S/C/X before creating a photo log. |
| 2 | Will users notice that the correct action is available? | Yes | S, C, and X controls remain visible on uncopied tiles, and shortcuts still work. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | The source inbox line says these are source decisions, not copied archive state. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | Counts update in the source inbox next-action text and creation becomes available only when the plan can create. |

**Verdict:** Pass.

## Step 4 - Create a new photo log from source decisions

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | Create Photo Log is available only from a source inbox with uncopied decisions. |
| 2 | Will users notice that the correct action is available? | Yes | The Photo Logs library and command surfaces expose Create Photo Log when the plan is valid. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | The source inbox copy/help text says creation starts a log and copied/on-disk photos are locked. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | The context changes to Active Photo Log after creation/opening, and the status names the created log. |

**Verdict:** Pass.

## Step 5 - Continue or append to an existing log

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | The Photo Logs tab explains Continue versus Add Marked in the next-action line. |
| 2 | Will users notice that the correct action is available? | Yes | Continue and Add Marked are visible per-log actions when each action is valid. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | Continue opens the log for review/copying; Add Marked appends current source-inbox S/C/X decisions. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | The active context changes to Active Photo Log and new uncopied S photos become copyable. |

**Verdict:** Pass.

## Step 6 - Copy the active photo log and proceed next

| # | Question | Answer | Reason |
|---|---|---|---|
| 1 | Will users try to achieve the right result? | Yes | Active Photo Log guidance says Copy To Archive copies uncopied S photos in this log. |
| 2 | Will users notice that the correct action is available? | Yes | Copy To Archive, Open Archive Folder, Confirm Backup, Clean Source SSD, and Start New Photo Log stay grouped in the copy area. |
| 3 | Will users associate the correct action with the result they're trying to achieve? | Yes | Copy readiness distinguishes uncopied S photos, verified copied files, backup confirmation, and cleanup. |
| 4 | After the action is performed, will users see that progress is made toward the goal? | Yes | Workflow guidance changes to copying, copied, backup, cleanup, or start-new-log states. |

**Verdict:** Pass.

## Summary

- Total steps: 6
- Failing steps: 0
- Fixes suggested: 0

### Failing steps and fixes

All steps passed. No fixes required at this granularity.

## Method note

This walkthrough was conducted by an AI agent adopting the persona above and applying the Nielsen Norman cognitive walkthrough method (<https://www.nngroup.com/articles/cognitive-walkthroughs/>). The findings are an expert-style inspection of learnability for new users; they are not observed behaviour from real users and should not be treated as evidence of how actual users will behave. Use them as inputs to design revision, not as a substitute for usability testing.
