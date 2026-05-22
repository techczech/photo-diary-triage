# Cognitive Walkthrough

## Task

- User opens the Photo Logs disclosure and wants to choose the correct log action.

## Step 1: Recognise The Log

- Right result: User needs to identify the log by title and scope.
- Notice action: Title is the strongest text in the row; scope is shown above the list.
- Association: Source path and count badges confirm the log identity.
- Progress feedback: Current log badge shows when the selected log is open.
- Result: Pass.

## Step 2: Understand State

- Right result: User needs to know whether the log is current, copied, locked, or missing source.
- Notice action: Current and status badges appear near the title.
- Association: Lock message appears under the row actions only when relevant.
- Progress feedback: Disabled Edit/Delete actions are paired with the lock message.
- Result: Pass.

## Step 3: Choose Action

- Right result: User needs Continue, Contents, Details, Edit, or Delete.
- Notice action: Actions wrap in a stable grid below the metadata.
- Association: Primary Continue action appears first; Details and Contents remain visible.
- Progress feedback: Existing app state changes after opening a log or sheet.
- Result: Pass.
