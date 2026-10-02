---
item_id: PDT-2026-10-02-111
title: Responsive bounded Archive cover loading
status: shipped_pending_native_acceptance
target_release_version: 0.7.15
target_build: 151
target_feature_slug: archive-cover-loading
source: Original WP3 fast indexed Archive browsing and Travel byte-read contract
---

# Responsive Archive covers

Archive cards synchronously validate paths and open NSImage in their SwiftUI body. Move
all thumbnail filesystem checks and decoding off the main thread, with explicit limits
on active decodes, queued distinct covers and retained decoded bytes. Read only resident
JPEGs below _index/thumbs; reject leaf and ancestor symlinks even to originals inside
the archive. Never generate, hydrate or fall back to originals for covers.

## Implementation and constraints

Bind cover identity to root, byte policy generation, accepted catalogue revision, indexed
thumbnail path and a bounded display pixel size. Visible cards own cancellable subscriptions;
hidden previews and disappeared cards do no new file work. Deduplicate shared requests,
prioritise visible requests, retain cancelled noncooperative decodes in their occupied slot,
and retry deferred admission without dropping still-visible covers. Guard publication and
cache insertion against stale context. Use a hard LRU count and byte budget. Keep full-size
Preview separate from cover concurrency. Also revoke generation-stale Preview caches and
prevent Travel original preheating even when explicit viewing consent exists.

## Meaningful test conditions

First reproduce the shared decoder generation-cache and Travel preheat defects. Test
real JPEG downsampling, corrupt/missing/traversal/linked paths, simulated online-only
thumbs, worker thread, physical active/queue bounds, cancellation before validation,
shared subscription cancellation, visible priority, admission retry, cache count/bytes,
root/role/revision changes, model reuse and Preview independence. Run full regression
suite, Astra review, signed bundle verification and closed-app installation. No live
archive writes or headed app testing while Dominik is away.

## Success criteria and remaining scope

Archive cover rendering reads no files on the main thread, resource use has enforced
limits, and stale work cannot appear on current cards. Automated fixtures prove these
properties. Native scroll/layout acceptance remains pending. The complete command
registry, reserved shortcuts, rebinding, generated help and sidebar focus remain the
next implementation slice (112), together with real key-event regression tests; they
are not treated as native-only gates. Original migration/OneDrive/LM Studio/Google
acceptance gates remain explicit. Dominik has authorised independent development and
Astra consultation; this concrete spec proceeds without routine clarification.
