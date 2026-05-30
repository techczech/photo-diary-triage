# Map + location assignment — design brief

## Goal

During triage, let the user record WHERE a walk (and later its days/clusters/photos)
happened — by name and by a point on a map — even when photos carry no GPS. Plus plot any
photos that do have GPS.

## Placement

- Inline panel inside the review pane, toggled by a "Map" button in the review toolbar.
- Fixed panel height; the map fills the panel below a one-row assignment bar.
- Grid remains below the panel and stays the primary surface.

## Layout (panel, top to bottom)

1. Assignment bar (only in an editable session): location-name field · "Pin to map centre"
   · "Save Location" (enabled only with unsaved changes) · "Clear" (only if a location is
   saved) · short pin-status text.
2. Map fills the rest. Photo-GPS pins blue; the walk pin orange.

## States

- S1 Editable session, no location yet, no photo GPS: map visible at a default region;
  empty name field; status "click the map or use the button to drop a pin".
- S2 Editable session, location saved: name shown; orange walk pin shown; map centred on it.
- S3 Editable session, photos have GPS: blue pins plotted; assignment still available.
- S4 Read-only context (archive walk): no assignment bar; blue pins if GPS; else a clear
  "no GPS / read-only" empty state.
- S5 Panel toggled off: nothing (grid full height).

## Interactions

- Toggle Map → panel appears/disappears.
- Drop/move the walk pin: (a) click anywhere on the map, or (b) pan so the target is at the
  centre and press "Pin to map centre". Two paths because the click→coordinate conversion
  cannot be GUI-verified by the author; the centre button is the guaranteed path.
- Type a name; Save Location persists name + pin on the session (durable across launches).
- Clear removes name + pin.
- Pan/zoom: standard map gestures; also drives the centre button.

## Persistence

- WalkMetadata.location (name, already existed) + new WalkMetadata.latitude/longitude
  (optional, backward-compatible Codable).
- Saved through the normal session save path, so it survives relaunch and recovery.
- Follow-up: also write the coordinate into the walk `.md` manifest on copy (the name
  already is written).

## Non-goals (this slice)

- Day / time-cluster / individual-photo assignment (C.3).
- Reverse geocoding a name from a pin (optional later).
- Archive-walk assignment (needs manifest rewrite; research item R4).

## Known author-side risks (cannot GUI-verify)

- R-A: a Map with no explicit fill frame collapses to zero height in a VStack → invisible.
  Mitigation: force `maxWidth/maxHeight: .infinity` on the map and its container. (This was
  the reported "no map" bug.)
- R-B: MapKit could render a blank tile area if the map is shown but tiles fail. Distinct
  from R-A; if it recurs after the fill fix, treat as a MapKit/availability issue.
- R-C: click→coordinate conversion may not fire. Mitigation: "Pin to map centre" fallback.
- R-D: assignment bar may clip on a narrow review pane. Mitigation: keep it one compact row;
  revisit with a wrapping layout if it clips.
