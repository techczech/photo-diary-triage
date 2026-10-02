---
item_id: PDT-2026-10-02-111
title: Responsive bounded Archive cover loading
status: shipped_pending_native_acceptance
release_version: 0.7.15
build: 151
feature_slug: archive-cover-loading
---

# Responsive Archive covers

Timeline, Contact Sheet, Walk and search-photo cards now read prepared thumbnails through
an asynchronous dedicated queue. The SwiftUI body performs no filesystem validation or
image open. Accepted catalogue revision and byte-policy generation join the root/path in
the request identity. Hidden previews and disappeared cards cancel their subscriptions;
view updates after disappearance do not start new work. Model request/context guards
prevent an old image from flashing on a reused card.

The queue permits three physical decoders and 128 distinct pending covers. It deduplicates
shared subscriptions, promotes visible requests and allows a visible card to displace
queued speculation at capacity. Deferred visible admission retries while the card remains
visible. A cancelled noncooperative worker retains its physical slot until it actually
returns. One subscriber's cancellation leaves the other subscriber intact. The LRU retains
at most 128 CGImage buffers and 64 MiB of decoded buffer bytes, counted with actual padded
bytesPerRow times height. Images above 512 pixels are rejected before publication. Full-size
Preview has a separate decode path and remains usable while cover work is suspended.

Covers accept only resident JPEGs under _index/thumbs. Descriptor-relative O_NOFOLLOW
traversal rejects ancestor/leaf links even to originals inside the same archive; the
configured archive-root alias remains supported. Bounded file size, regular-file, inode,
SF_DATALESS and allocation checks reject unsafe inputs. The entire synchronous root/path/
byte operation disables dataless materialisation on its current worker thread and restores
its previous policy; unavailable policy fails closed. This follows
[Apple TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files).
It never applies process-wide or across an await, and cannot revoke explicit Preview.
Missing, corrupt, online-only or linked inputs display the ordinary placeholder. No
thumbnail generation, original fallback or explicit download occurs during cover loading.

The shared Preview decoder now discards generation-stale caches and guards the captured
generation before work and publication. Travel preheat is rejected even when a particular
resident original has explicit viewing consent; direct full-size viewing remains allowed.

## Files and verification

ArchiveCoverLoading.swift owns request/source/queue/cache/model responsibilities.
ArchiveBrowserViews, UIState and AppState provide catalogue context and view lifecycle;
ArchiveIndex adds filesystem-free policy identity matching. DecodedImagePipeline contains
the narrow cache-generation and preheat corrections.

ArchiveCoverLoadingTests.swift adds 24 test functions, including two cache-limit cases.
The two original shared-decoder defects reproduced before fixes:
 /private/tmp/walkfolio-covers-before.log
Astra then found full-queue visible admission, padded-buffer accounting and dataless-policy
gaps; all three reproduced before correction:
 /private/tmp/walkfolio-covers-astra-before.log
Actual JPEG worker decoding/downsampling, sparse-placeholder rejection before byte open,
linked ancestor/leaf paths, root aliases, cancellation before file work, physical-worker
lifetime, shared subscriptions, priority/promotion, deferred retry/cancellation, hard
count/byte LRU, policy/root/revision changes, model reuse and independent real Preview pass.
Production-limit stress holds three workers and 128 queued requests while 100 more defer.
Policy failure and restoration and oversized injected pixel rejection also pass.

All 447 tests pass in 23.777 seconds (baseline 190):
 /private/tmp/walkfolio-covers-full.log
The final test-only Swift 6 warning correction preserves the actual worker probe:
 /private/tmp/walkfolio-covers-worker-final.log
Astra's final read-only source review found no remaining material defect. It did not run
native scrolling or certify actual OneDrive behaviour.

Real bundle build/signing:
 /private/tmp/walkfolio-covers-bundle.log
Installed 0.7.15/151 while closed. Strict/deep signature, installed-to-signed-bundle equality,
compiled-to-bundle body equality after removing signatures from temporary copies, and
release metadata checks passed. Previous real app:
 /private/tmp/Walkfolio-before-cover-loading-0.7.15.app

## Remaining work

Original WP3 complete keyboard/sidebar implementation continues in the next slice. The
keyboard audit found duplicate focus/grouping chords, reserved-key conflicts and separate
hard-coded help. A command registry, effective persisted overrides, palette/contextual
actions, generated help, reserved surfaces and real event-path tests remain required.
Native scroll/layout/focus, copied historical/migration, actual OneDrive, chosen LM Studio
vision model and Google test-account acceptance remain explicit. Version 1.0 is unaccepted.
No headed launch, real archive mutation or private-photo delivery ran. Exact-version return
checks use synthetic index-only material; no watcher runs.
