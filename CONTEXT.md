# Walkfolio

The domain language for Walkfolio (working repo name: photo-diary-triage) — a local-only
macOS photo archive manager with a strong triage component. The product's centre of gravity
is the Archive — a 20-year photo diary — with triage of new photos as the primary way
material enters it. Walk and Trip are deliberately opinionated terms; their UI display
labels are user-configurable, but the model names below are canonical in code and manifests.

## Language

**Archive**:
The structured on-disk photo diary (year/trip/walk folders plus Markdown/JSONL manifests).
The primary object the app manages — browsed, described, and extended over time.
_Avoid_: library, catalog (the catalog is the in-app SQLite cache, never the source of truth)

**Triage**:
The act of importing Walks from Sources and organising them into Trips — reviewing, keeping,
discarding, describing. Also names the persisted working state of one such sitting ("an
unfinished Triage"). A component of the product, not its whole identity.
_Avoid_: culling, editing, import session (legacy code term for the working state)

**Walk**:
One photographic outing — a walk, an afternoon at an event — possibly drawn from several
Sources (camera + phone). The unit a Trip is made of; several Walks can happen in one day.
_Avoid_: session, outing, shoot

**Trip**:
A named group of Walks the diary tells one story about — a holiday, a journey, or a month's
ordinary outings. The unit the Archive is organised and browsed by, and a physical folder on
disk. Every Walk belongs to exactly one Trip; a Walk never spans two. The plain month itself
is the **default Trip** for Walks that belong to no named one.
_Avoid_: collection, holiday, event (kinds of Trip, not model terms)

**Source**:
An external volume or folder (typically the camera SSD, or an old photo folder during
historical processing) that photos are triaged from. Never modified during triage; only
touched by explicit Cleanup.
_Avoid_: import folder, card

**Location**:
A place name plus coordinate attached to a Walk (pin-drop or GPS centroid), optionally
overridden per time-cluster or per photo. A Trip's location is derived from its Walks'
Locations, with an overridable label only.
_Avoid_: walk_location (legacy field)

**AI Description**:
A machine-generated description of an archived photo (or summary of a Walk/Trip), recorded
in manifests with the generating model and date. Regenerable on demand, never hand-edited,
and kept strictly separate from the user's own notes. Exists to make the Archive searchable;
occasional errors are acceptable.
_Avoid_: caption (implies human authorship), notes (those are the user's words)

**Photo Log**:
A curated, named set of photos drawn from the Archive for use outside it — copied to disk or
pushed to Google Photos. Membership is recorded in manifests and shown as badges.
_Avoid_: album, export set

**Manifest**:
The durable Markdown/JSONL text record of a Trip, Walk, or file, written alongside the
photos. The canonical source of truth; nothing important may exist only in a database.

**Archive Index**:
A derived, read-only, rebuildable JSONL summary of every manifest (plus small thumbnails)
in one pinned `_index/` folder, so any machine can browse, search, and map the Archive
without photo bytes. When it disagrees with Manifests, Manifests win.
_Avoid_: catalog, database (the SQLite cache is yet another derived layer)
