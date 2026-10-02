---
item_id: PDT-2026-10-02-104
title: Historical folders through safe ordinary triage
status: implemented_pending_native_check
target_release_version: 0.7.8
target_build: 144
target_feature_slug: historical-triage
---

# Historical triage

The approved completion plan requires old pre-culled folders to use ordinary Triage. Explicit historical intent starts new items kept, preserves the selected root and records source/date provenance. Saved identities, exclusions and RAW choices survive reload; newly found items get historical defaults. Folder/path titles and complete/month/year date hints are proposals. Prefer valid camera dates; expose a reviewable folder-date preference for conflicts, keep the original date and partial-date precision distinct, and pass effective dates into grouping, destination planning and canonical manifests.

Repair normal Copy retry: persist confirmed Walk/Trip proposals before the first file, reuse that exact plan after failure/reopen, and retain safety rejection of changed sources/selections/metadata. Tests must use AppState's actual Copy actions, not only direct service calls. Candidate archive matches based on filename/size/date must never become verified copies. Historical recognition uses verified bytes and portable paths without granting Cleanup eligibility.

Historical sources inside the Archive may be cleaned only as a narrow recorded-source exception after explicit confirmation, backup/main-role gates and complete digest verification of distinct imported destinations. Reject canonical Walk/Trip source material, symlinks/aliases, changed/missing copies and unsupported/uncopied files. Remove only verified imported files, never a source directory. Preserve the ordinary prohibition for other archive sources.

Acceptance tests cover default stance versus camera sources, reload preservation, date/title fixtures and real destination paths, new/existing Trips, equal-size different-byte candidates, recorded retry after an interrupted copy, canonical reconstruction, and cleanup refusals/success/retry. Native interface and actual OneDrive behaviour remain separately reviewable. Trip label, descriptions and Google Photos remain approved follow-ups.
