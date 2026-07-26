# Slice RFC-0118: Backup Asset Recovery And Release Readiness

## Status

Proposed.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0101: Cloud Backup Snapshot Foundation
- Slice RFC-0102: CloudKit Atomic Backup Publication
- Slice RFC-0105: CloudKit Full Restore
- Slice RFC-0107: Manual Full-App Backup
- Slice RFC-0113: Manual Cloud Backup Freshness And Cellular Consent

## Goal

Keep one unavailable referenced Photos asset from permanently blocking fresh recovery backups, while
making every omitted photo an explicit owner decision and proving the resulting CloudKit backup can
restore a signed release build on a real iPhone.

## Scope

1. Distinguish a genuinely unavailable Photos asset from permission, cancellation, mutation,
   encoding, storage, and other snapshot failures.
2. Collect all unavailable Photos references found during one snapshot attempt instead of stopping
   at the first reference.
3. Pause an owner-requested cloud or manual-file backup before publication or export and explain how
   many unavailable photos were found.
4. Offer three owner choices:
   - **Back Up Without Photos** omits the unavailable photos from the recovery snapshot while leaving
     the current local CloudBake records unchanged.
   - **Remove From CloudBake And Back Up** removes only the broken CloudBake photo references after a
     separate destructive confirmation, then creates a fresh snapshot.
   - **Cancel** leaves local data, backup exclusions, and the last successful cloud snapshot
     unchanged.
5. Persist an owner-approved omission by opaque photo-reference identity so future automatic and
   manual backups do not repeatedly fail on the same unavailable photo.
6. Reconsider an omission when its source reference changes or is removed. A future explicit
   recovery-management UI may also clear approved omissions.
7. Produce an internally complete snapshot when photos are omitted:
   - clear omitted design photo references in the captured database,
   - clear matching order customer-reference links,
   - remove matching order-photo rows from the captured database,
   - exclude the unavailable payloads from the manifest,
   - record only the omitted count in backup metadata, never a customer-facing filename or Photos
     identifier.
8. Report a successful backup truthfully when it omitted owner-approved unavailable photos.
9. Preserve the previous current CloudKit generation until the replacement snapshot has uploaded,
   validated, and published atomically.
10. Correct the release runbook so it distinguishes implemented CloudKit full restore from the
    proposed direct `.cloudbakebackup` import workflow.
11. Perform and record a real-device disaster-recovery drill using the signed release candidate and
    the production CloudKit environment.

## Out Of Scope

- Direct import of a `.cloudbakebackup` file.
- Selective data restore.
- Restoring an unavailable original-resolution Photos asset.
- CloudKit multi-device synchronization.
- Automatically deleting live CloudBake records without owner confirmation.
- Treating denied Photos permission, a transient iCloud Photos download failure, cancellation,
  changed source data, encoding failure, or insufficient local storage as an unavailable photo.

## Owner Experience

When **Back Up Now** or **Create Full Backup** finds unavailable Photos assets, CloudBake shows one
decision after the complete scan:

> Some referenced photos are no longer available in Photos. CloudBake can continue without those
> photos, remove their broken CloudBake references, or cancel. Your previous cloud backup and local
> data remain unchanged until you choose.

**Back Up Without Photos** is non-destructive to the active installation. The resulting recovery
snapshot intentionally does not contain the affected photo records. Settings reports, for example,
**Backed up without 2 unavailable photos**.

**Remove From CloudBake And Back Up** requires a second confirmation because it changes the active
installation. It removes only records that point at the exact unavailable references. It never
deletes anything from the iPhone Photos library.

Automatic backup may reuse only omissions that the owner previously approved. A newly unavailable
photo stops that automatic attempt safely, preserves the last valid generation, and leaves an
actionable Settings status for the owner. Automatic backup must never make a new omission decision.

## Data And Integrity Design

Store approved exclusions locally using a stable digest of the Photos reference rather than
customer metadata or the raw Photos identifier. The captured database is rewritten only after the
asset resolver proves the matching source is unavailable or an existing approved exclusion matches
that source.

The backup manifest adds a backward-compatible optional omitted-asset count. Format version 1
decoders treat an absent count as zero. No omitted path, caption, order ID, customer name, design
name, or Photos identifier is uploaded as omission metadata.

A source is eligible for the unavailable-photo decision only when PhotoKit reports that the asset
cannot be found. Limited or denied Photos access is an authorization failure with guidance to change
permission, not proof that the photo was deleted. Cloud or local-provider download errors remain
retryable failures.

## Disaster-Recovery Drill

The drill must use a signed build configured for the production CloudKit container and an iCloud
account that contains disposable test data.

Record:

1. exact git SHA, marketing version, build number, device model, iOS version, date, and CloudKit
   environment;
2. creation of representative customer, order, recipe, inventory, design, custom-logo, and photo
   data;
3. successful **Back Up Now** publication and Settings last-success evidence;
4. confirmation that the production current pointer references the new validated generation;
5. clean-install or disposable-installation restore discovery;
6. explicit full-restore confirmation;
7. restored record counts and representative field checks;
8. restored design, order, and branding image checks;
9. post-restore relaunch, reminder reconciliation, and fresh-backup behavior;
10. any omission decision and proof that the reported omitted count matches the restored result.

Evidence must not contain customer names, phone numbers, private notes, photo contents, raw Photos
identifiers, CloudKit user record names, or payload filenames.

## Test Plan

- Unit:
  - classify only a missing PhotoKit asset as unavailable;
  - collect multiple unavailable references;
  - persist opaque approved exclusions;
  - leave exclusions unchanged on cancel;
  - render truthful omitted-photo status.
- Integration:
  - omit design and order photo references only in the captured database;
  - remove exact live references transactionally after destructive confirmation;
  - keep unrelated photo records and Photos assets;
  - validate a snapshot with zero or multiple approved omissions;
  - preserve the previous CloudKit generation when a new unapproved asset is unavailable;
  - publish and restore an owner-approved omission snapshot.
- Acceptance:
  - **Back Up Now** presents one unavailable-photo decision;
  - cancel preserves local state and previous backup;
  - omit continues to a successful backup with truthful status;
  - remove requires a second confirmation and continues successfully;
  - denied Photos access does not offer destructive missing-photo choices.
- Manual:
  - complete the production-like real-device disaster-recovery drill above.

## Acceptance Criteria

- One unavailable Photos asset cannot permanently prevent future backups after the owner chooses an
  omission or removal outcome.
- No unavailable photo is silently omitted by an automatic backup.
- Omission changes only the recovery snapshot and persisted exclusion decision, not active business
  records.
- Removal changes only exact broken CloudBake references and never deletes from Photos.
- Every successful snapshot is internally consistent and passes existing checksum, compatibility,
  path-containment, and atomic-publication validation.
- The last successful cloud generation remains restorable through every cancel, preparation failure,
  and pre-publication failure.
- Settings states whether the latest success omitted unavailable photos.
- A signed production-like build completes a recorded CloudKit full-restore drill before App Store
  submission.

## Documentation And Wiki

- Correct `docs/app-store-release-runbook.md` to name CloudKit restore explicitly and state that
  direct `.cloudbakebackup` import remains unavailable.
- Extend `docs/cloudkit-backup-operations.md` with the exact production drill and evidence template.
- Update `wiki/Owner-Workflows.md`, `wiki/Current-App-Capabilities.md`, and `wiki/Privacy-Policy.md`
  with the unavailable-photo decision, omission meaning, and retained-backup guarantee.

## Rollout Notes

Ship the owner decision before relying on automatic backups for release evidence. The release
candidate is not disaster-recovery complete until the real-device drill is recorded successfully.
