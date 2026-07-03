# Archive Index: derived JSONL + thumbnails in one pinned `_index/` folder

The travel machine must browse, search, and map the whole Archive without downloading
photos, but OneDrive Files On-Demand offers no by-extension pinning — keeping thousands of
scattered per-photo `.md` manifests local is impractical. We therefore maintain a single
top-level `_index/` folder at the archive root, pinned "Always keep on this device" once per
machine, containing (a) an archive index as JSONL sharded by year (one entry per
photo/walk/trip, including AI descriptions) and (b) the small per-keeper thumbnails
(`thumbs/<year>/…`, ~512px) generated at import.

Rules that make this safe:

1. Individual manifests beside the photos remain the canonical durable record; the index is
   derived, read-only, and rebuildable at any time. On disagreement, manifests win.
2. The index is written only on the main archive machine — incrementally after every
   import/metadata edit, plus an explicit full "Rebuild index" repair command.
3. Travel-machine metadata edits write directly to the tiny individual manifest (hydrates on
   write, syncs back); the next main-machine rebuild absorbs them. No merge protocol needed —
   conflicts are structurally avoided rather than resolved. (Rejected alternative: an edit
   queue merged later — more machinery for the same result.)
4. Travel mode never reads archive photo bytes without an explicit "Download to view";
   online-only files are detected via the allocated-size≈0 heuristic (no public dataless API
   exists).

Rejected alternative: pinning the manifest files themselves — impossible to automate under
File Provider; and per-walk `.thumbs/` folders scattered through the tree, which would
have the same unpinnable-at-scale problem the index solves.
