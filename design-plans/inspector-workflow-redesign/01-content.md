# Inspector Workflow Redesign Content

## Primary Scenario

- A photo log has already been copied.
- The user needs to inspect the archive folder on disk, confirm backup, then optionally clean copied source files from the SSD.

## Required Labels

- Inspector
- Photo Log Copied
- Copied archive folder
- Open Archive Folder
- Confirm Backup
- Clean Source SSD
- Current Log
- Source
- Triage
- Photo Logs
- Storage Details

## Example State

- Title: Morning Birdwatch Near Blenheim
- Source: `/Volumes/EOS_DIGITAL/DCIM`
- Archive folder: `/Volumes/BigData/PhotoArchive/2026/03/morning-birdwatch-near-blenheim`
- Visible items: 399
- Triage: 57 selected, 1 candidate, 341 excluded
- Workflow state: Ready for source cleanup

## Actions

- Copy To Archive
- Open Archive Folder
- Confirm Backup
- Clean Source SSD

## Safety Messages

- Copied photos are in the archive folder.
- Backup confirmation is separate from opening the folder.
- Source cleanup is available only after confirmation when that setting is enabled.
