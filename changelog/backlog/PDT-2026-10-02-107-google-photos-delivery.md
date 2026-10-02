---
item_id: PDT-2026-10-02-107
title: Original-quality Google Photos delivery with durable membership
status: shipped_pending_native_and_provider_validation
target_release_version: 0.7.11
target_build: 147
target_feature_slug: google-photos-delivery
source: Approved completion plan WP6 and independent-development authorisation
---

# Google Photos delivery

Explicitly send a captured canonical Trip or imported Photo Log to one app-created album. A review sheet identifies the connected account, album, exact original count and bytes before sending. No delivery during ordinary triage, automatic startup or development; private external delivery requires the user's concrete destination action. Preserve exact original bytes and their local hashes, with no transcoding, quality downgrade or machine-generated description fields.

Desktop OAuth uses a system browser, loopback callback, state and PKCE. Configure a Desktop client ID; optional client secret, access/refresh tokens and transient upload sessions/tokens stay in Keychain. Request appendonly, readonly.appcreateddata and minimal OpenID identity for account binding. Verify granted scopes and authenticated subject. Account/client/root/role changes invalidate captured work; never resume into another account.

A durable serial queue records album intent and per-photo evidence before requests. Reuse canonical album bindings. Album creation has no documented idempotency: an unknown result must reconcile with app-created albums and explicit selection, never silently create another. Upload exact originals through bounded resumable chunks, query server offsets after interruption, handle session/token expiry, serialise media creation per account, persist responses before local facts and verify album membership. Google's byte deduplication permits retrying exact bytes; a successful remote creation followed by local write failure must not cause a new album or forgotten receipt. Quota/rate limiting is visible and respects retry timing. Cancellation stops further requests; Resume is explicit.

Canonical photo/Trip manifests retain account-scoped album and membership facts. Manual previously-synced marks are explicitly unverified recollections, never API verification or cleanup proof. Badges survive index rebuild, relocation and index-only Travel. Travel delivery must not implicitly hydrate/read originals; only existing explicit byte grants may be used. Canonical notes, machine descriptions, IDs and original GPS survive edits and moves.

Inject transport, credentials, Keychain and durable-write failures. Cover OAuth PKCE/state/scope denial, account changes, original bytes, interrupted chunk query, expired token/session, ambiguous album response, partial/failed media response, membership verification failure, local receipt failure, cancellation, rate limits and fresh index-only badges. Native sign-in and a live test-account upload remain a separately reviewable concrete validation step; no real account or photo is used during development.

Provider documentation checked 2026-10-02: Google Photos authorization scopes, resumable uploads, upload media, app-created album listing/membership search, and Google Desktop OAuth. The post-March-2025 API cannot inspect photos/albums created outside this app; manual marks remain necessary.

## Implementation result

Implemented in 0.7.11 build 147. All 350 tests pass, including the integrated camera/phone archive journey and actual AppState confirmation/cancellation/Travel routes. See the implementation report. Native Google test-account and whole-app acceptance remain separately reviewable.
