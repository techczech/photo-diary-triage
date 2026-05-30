# Map + location assignment — cognitive walkthrough

Method: step through the primary goal "assign a location to the current walk" and the
secondary goal "see where GPS photos are", asking at each step (1) will the user know what
to do, (2) will they see that it worked, (3) what breaks. Author cannot run the GUI, so each
step is reasoned against the code.

## Primary goal: assign a location to the current walk (no GPS in photos)

1. User is in camera triage with a photo log open, viewing the grid.
   - Q: how do they start? The review toolbar has a "Map" button (map icon + "Map").
   - Risk: discoverability among many toolbar buttons. Acceptable for now; revisit if lost.

2. User clicks "Map".
   - Expected: an inline panel appears above the grid.
   - ISSUE FOUND (reported by user): panel appeared but NO MAP was visible.
   - Cause: the `Map` sat in a VStack inside a fixed-height panel with no fill frame, so it
     collapsed to ~0 height. → FIXED: force maxWidth/maxHeight .infinity on the map + its
     container (0.2.51).
   - After fix: the map fills the panel under the one-row assignment bar.

3. User sees a map at some default region (no saved location, no GPS).
   - `.automatic` with no annotations may show a wide/default region.
   - Acceptable: the user pans to their area. After a location is saved, reopening centres
     on it. NOTE: first-use region may be wide; not blocking.

4. User pans/zooms to the right place.
   - Standard gestures. `onMapCameraChange` tracks the centre → enables "Pin to map centre".

5. User drops the walk pin.
   - Path A: click the map (MapReader + proxy.convert). Cannot be author-verified.
   - Path B (guaranteed): "Pin to map centre" sets the pin to the tracked centre.
   - Either way an orange "This walk" pin appears; status changes to "Pin set — Save…".
   - Verified-by-design: both paths set `pinCoordinate`, which renders a Marker.

6. User types a location name.
   - Plain TextField; onSubmit also saves.

7. User clicks "Save Location" (enabled because there are unsaved changes).
   - Persists name + pin on the session; status line confirms "Saved walk location: …".
   - Save button then disables (no unsaved changes) — visible confirmation it took.

8. User quits and reopens the log.
   - `syncFromWalkIfNeeded` reads the saved name + coordinate, shows the name, the orange
     pin, and centres the map on it. Confirms persistence.

9. User clicks "Clear".
   - Name + pin removed and persisted; status "Cleared walk location.".

## Secondary goal: see GPS photos (when any exist)

- Items with metadata lat/long render as blue markers, region auto-framed (C.1).
- GPS sign fix ensures UK/west coordinates plot correctly (unit-tested).
- For this user, most photos have no GPS, so this is usually empty — expected; the empty
  state explains it in read-only contexts.

## Edge cases reasoned

- Read-only/archive context: no assignment bar; blue pins if GPS, else empty state. OK.
- Narrow review pane: the assignment row could clip (R-D). Watch; switch to a wrapping
  layout if it does.
- Toggling Map off/on: local @State; re-sync happens once per session via `didSync`.
- Switching the open session while the panel is open: `onChange(currentSession?.id)` resets
  `didSync` and re-syncs name/pin/region. OK.

## Open questions for the user (do not assume)

- Q1 Default first-use region acceptable (wide, then pan), or center on a remembered
  last-used region?
- Q2 Is one inline row of controls enough, or do you want the assignment in a small
  side form next to the map?
- Q3 For C.3, where should day/cluster/photo location controls live — same panel with a
  target selector, or contextual (assign from a selected group/photo)?

## Test asks (only after this walkthrough)

- Toggle Map → a map is visible filling the panel.
- Pan to your area; "Pin to map centre" drops an orange pin; typing a name + Save persists;
  reopen confirms; Clear removes.
- Tell us whether clicking directly on the map also drops the pin (validates path A).
