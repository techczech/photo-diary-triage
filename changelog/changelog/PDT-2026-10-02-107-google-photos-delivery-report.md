---
item_id: PDT-2026-10-02-107
title: Original-quality Google Photos delivery and complete fixture workflow
shipped_release_version: 0.7.11
shipped_build: 147
shipped_feature_slug: google-photos-delivery
status: shipped_pending_native_and_provider_validation
---

# Walkfolio 0.7.11: recoverable album delivery

Settings offers explicit Google Desktop OAuth sign-in through the system browser, loopback callback, state and PKCE. Tokens, optional client credentials and transient upload handles stay in Keychain. Delivery reviews the authenticated account, captured canonical Trip or imported Photo Log, album and original count/bytes. Only the user's Send action starts a new delivery; ordinary startup and Triage send nothing. RAW companions and generated crops are excluded.

A durable serial queue records album intent and captured photo identities, sizes, whole-file hashes and fixed-block hashes. Uploads stream verified original bytes in bounded resumable chunks, query server offsets after interruptions and retry expired sessions/tokens using the same bytes. Account/client/root/role changes stop further requests. Quota pauses retain progress and respect retry timing; cancellation interrupts both preparation and active requests. New confirmed work runs only its own job. An unknown album creation result needs explicit reconciliation with a distinguishable album and inspection link before another creation can occur. Stopping a known delivery retains its binding for fresh work.

Remote media responses and verified membership are saved before canonical publication. Photo and Trip/Photo Log receipts are idempotent; local failures retry without another upload or forgotten owner receipt, including after abandonment and a fresh request. Canonical records preserve human notes, machine descriptions, IDs and GPS. Index projection retains account-scoped badges after rebuild and on fresh Travel roots. Generated crops have no inherited receipt and do not inflate original coverage. Manual previously-uploaded marks remain explicitly unverified; clearing them retains verified receipts. Historical marks do not promote folders into Trips.

Travel requires an existing exact original-viewing grant and resident bytes; delivery never hydrates. Current Travel photo, Walk, Trip and historical badges update through an in-memory metadata overlay while `_index` remains unchanged. Other machines receive those canonical changes after Main publishes its index. Stale paths in historical completed jobs cannot block a newer successful display refresh.

## Files changed

GooglePhotosAuthentication owns Desktop OAuth, account identity, refresh generation and Keychain storage. GooglePhotosClient owns injectable transport, app-created album pagination, upload protocol, serial media creation, membership verification and safe errors. GooglePhotosDelivery owns captured evidence, queue/recovery, account leases and canonical publication. GooglePhotosRecords owns framed immutable delivery facts and separate manual marks. AppState, GooglePhotosViews, SettingsView and Archive/review views expose reviewed send, queue, reconciliation and badges. Models, renderers, canonical editors and index projections preserve facts and keep them outside AI input baselines. GooglePhotosTests exercises protocol, service, actual AppState and the integrated journey.

## Verification

- **350 tests in two suites passed in 18.277 seconds**, up from 321 in the preceding release and 190 at the start of this review. Log: `/private/tmp/walkfolio-complete-journey-tests.log`.
- Exact original bytes, fixed-block mutation refusal, interrupted-offset retry, lost media response, expired upload handles and byte-deduplicated retries pass injected provider tests.
- Ambiguous album creation, cancellation during confirmed preparation, cancellation during unknown creation, explicit reconciliation and retained abandoned bindings pass without automatic duplicate album creation.
- Failed canonical owner saves, failed durable receipts, later fresh deliveries, quota pause/retry, malformed recovery progress, denied scopes, early loopback callbacks, old-refresh/new-sign-in races and hostile session URLs pass.
- Fresh index-only badges, crop exclusion, manual Walk marks, historical marks, Travel mark/clear, Travel Photo Log delivery and unchanged index digests pass. Moved historical receipt paths do not prevent fresh delivery updates.
- The full camera/phone fixture produces two same-day Walks in one named Trip, preserves human notes/raw GPS, assigns locations, generates six dependent descriptions, verifies three mock album members, removes and rebuilds the index, then browses/searches/maps a fresh Travel archive without originals. Google facts do not invalidate the current description baseline.
- Astra reviewed the implementation and final corrections; its final focused review found no remaining material issues. A prior public-source Claude Opus consultation informed recovery design. Review and mock results do not establish live provider success.
- Built and installed **0.7.11 build 147** while closed. Strict deep signature and built/installed executable equality passed. Previous app: `/private/tmp/Walkfolio-before-google-photos-0.7.11.app`.
- No live Google sign-in, private-photo delivery, real-archive migration/cleanup, implicit hydration or headed UI launch occurred. The synthetic loopback test uses a local ephemeral listener and fixture code only.

## Provider contract and remaining acceptance

Google Photos permits listing/verification of this app's created data; earlier uploads remain manual recollections. The API's membership result does not provide a remote SHA-256 comparison and must not serve as byte-verified cleanup permission. Album creation has no documented idempotency; an unknown result remains unresolved until explicit reconciliation. Cooperative locks are local, not distributed across OneDrive machines. Resumable handles are local to this Mac's Keychain.

Provider contracts checked on 2026-10-02: [Photos authorisation](https://developers.google.com/photos/overview/authorization), [original upload and limits](https://developers.google.com/photos/library/guides/upload-media), [resumable upload](https://developers.google.com/photos/library/guides/resumable-uploads), [app-created access](https://developers.google.com/photos/library/guides/access-media-items), [media creation](https://developers.google.com/photos/library/reference/rest/v1/mediaItems/batchCreate), [membership search](https://developers.google.com/photos/library/reference/rest/v1/mediaItems/search), [album listing](https://developers.google.com/photos/library/reference/rest/v1/albums/list), [album creation](https://developers.google.com/photos/library/reference/rest/v1/albums/create), and [Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app).

Native controls, real Google test-account authorisation/delivery, local LM Studio quality, actual OneDrive behaviour and the approved real-copy historical/migration acceptance remain open. The complete 1.0 scope remains committed; this is a tested implementation release, not a claim that all live acceptance criteria have been met. The consolidated native request asks for this exact version and supersedes earlier version-specific checks for current testing.
