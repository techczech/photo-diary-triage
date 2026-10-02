---
item_id: PDT-2026-10-02-106
title: On-demand local descriptions and recoverable historical batches
shipped_release_version: 0.7.10
shipped_build: 146
shipped_feature_slug: local-descriptions
status: shipped_pending_native_and_local_model_check
---

# Walkfolio 0.7.10: descriptions remain recoverable facts

Archive offers explicit photo descriptions, Walk summaries, Trip overviews and a selected-year historical queue. Settings expose the LM Studio OpenAI-compatible endpoint, read-only model discovery and explicit model selection. No inference starts during Triage. Travel uses only pinned thumbnails; Main may prepare a bounded preview of a resident original. Missing or linked inputs fail visibly without hydration.

Machine facts occupy a separate owned manifest section with immutable revisions, actual/requested model, generation date, endpoint, prompt version, target identity, input digest and child coverage. Successful regeneration replaces the active result; failure preserves the prior result and notes. Model text containing section-marker words remains valid data. Canonical reconstruction and main index/search use only active text, including after archive relocation. Travel saves tiny canonical records without publishing the index.

The serial queue records the complete batch before individual jobs, then saves each completed response before canonical publication. Network requests run outside the archive lock. Final checks cover identity, human baseline, expected active revision, source bytes, current child evidence, archive role/root and unchanged whole manifest text. Failed child refreshes cannot create freshly dated stale parent summaries. A successful canonical save followed by receipt failure retries without another model call or duplicate revision. Cancel interrupts the active request; describing new material leaves an unrelated cancelled batch stopped. Explicit Resume retries recorded work, while Discard failed batches releases every unfinished dependent job.

## Files changed

MachineDescriptions owns framing, revision history and human-text separation. LMStudioDescriptionClient implements explicit model discovery, bounded image/text payloads and safe protocol errors. ArchiveDescriptionQueue provides canonical input validation, dependency evidence, persisted batch/job recovery and publication. AppState captures targets and context; DescriptionQueueView, SettingsView and ContentView expose contextual controls. Models, ManifestRenderer, ArchiveManifestText, TripManifestStore and ArchiveIndex preserve facts through appends, labels, moves, reconstruction and search. DescriptionTests covers transport, service and actual AppState routes.

## Verification

- All 321 tests in two suites passed in 15.126 seconds, up from 297. Full log: `/private/tmp/walkfolio-descriptions-dependency-tests.log`.
- Injected image/text responses, model IDs, malformed/empty/truncated output, authentication/quota failures and redirects pass protocol tests.
- Failed writes, response-ready restart, successful-save/receipt failure, cancellation, scoped new work, failed-batch discard and parent retry pass without duplicate publication.
- Changed identity, notes, membership, role/root, linked manifests/thumb ancestors and changed input bytes refuse publication. Previous summaries survive failed photo or Walk refreshes; retry replaces them once.
- Separate Pictures roots, legacy records without copy hashes, exact bounded summary coverage, description search after moves and fresh index-only Travel without originals pass.
- Astra's final focused read-only review found no remaining concrete blockers. Review is distinct from runtime evidence.
- Packaged and installed 0.7.10 build 146 while closed. Strict deep signature verification and built/installed executable equality passed. Previous app retained at `/private/tmp/Walkfolio-before-local-descriptions-0.7.10.app`.
- A read-only models request to local LM Studio failed because no server was listening. No real inference, private-photo delivery, original hydration, real-archive mutation or native UI launch occurred.

## Limits and next work

Native controls, real model vision capability/quality and actual OneDrive behaviour remain separately reviewable. Model discovery does not certify vision support. Machine facts retain generation provenance after moves; they do not silently rewrite historical inputs. Cooperative archive locking is local, not distributed across OneDrive machines. Google Photos OAuth, append-only delivery and verified membership remain approved implementation work.
