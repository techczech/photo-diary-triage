---
item_id: PDT-2026-10-02-106
title: On-demand local descriptions and recoverable historical batches
status: shipped_pending_native_and_local_model_check
target_release_version: 0.7.10
target_build: 146
target_feature_slug: local-descriptions
source: Approved completion plan WP5 and independent-development authorisation
---

# Local descriptions

Describe canonical archived keepers, Walks and Trips on explicit request; never start work during Triage. Settings expose the LM Studio OpenAI-compatible base URL and explicit model selection. Refresh models is read-only. Image descriptions use bounded local input; Travel uses pinned thumbnails exclusively and never reads, generates or hydrates originals. Missing inputs produce a resumable visible failure.

Canonical manifests store immutable machine revisions with model, generation date, input digest/type/coverage, target identity and prompt version. Exactly one successful revision is active; regeneration replaces active text, never merges, and failure retains the prior result. Human notes and unknown fields remain separate and intact. Main index publication and search use only active text; Travel does not publish the index.

A durable serial queue snapshots target paths/identities, expected active revision, model/endpoint and canonical baseline before requests. Historical scope can queue all canonical material in the selected year. Photo jobs precede Walk summaries and Trip overviews; bounded summaries record child revisions, omissions and coverage. Network calls occur outside the archive lock. Persist a completed response before atomic canonical commit, reread evidence and expected revision, refuse changed identity/membership/edits, and use job IDs for idempotent retry after a successful save and failed receipt. Resume interrupted jobs without duplicating committed revisions. Cancellation before or after a request prevents unfinished publication; no automatic resume during triage.

Acceptance tests inject transport and failures for image/text payloads, model discovery, malformed/empty/errors, response-ready recovery, stale edits/moves, changed summary membership, failed regeneration, selection/root/role changes and Travel without originals. Canonical reconstruction and active-only search must pass. Native controls and real LM Studio quality remain separately reviewable; no private archive inputs are sent during development.

Provider references checked on 2026-10-02: https://lmstudio.ai/docs/developer/openai-compat/chat-completions and https://lmstudio.ai/docs/developer/openai-compat/models .
