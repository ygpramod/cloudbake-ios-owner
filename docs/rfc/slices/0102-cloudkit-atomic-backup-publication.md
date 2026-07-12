# Slice RFC-0102: CloudKit Atomic Backup Publication

## Status

Implemented.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0101: Cloud Backup Snapshot Foundation

## Goal

Publish a validated snapshot to the owner's private CloudKit database without risking the last
successful recovery snapshot.

## Scope

1. Configure the CloudKit container, owner-app capabilities, private schema, and environment process.
2. Implement `CloudBackupStoring` behind CloudKit-free application interfaces.
3. Upload the manifest, database, and assets into a non-current generation.
4. Verify uploaded content and conditionally publish the current-generation pointer.
5. Remove the superseded generation and safely collect abandoned non-current generations.

## Out Of Scope

- Background scheduling, Settings controls, restore, deletion UI, and sync conflict resolution.

## Design

Use one current-pointer record and generation-scoped manifest, database, and CKAsset records in the
owner's private database. Publication uploads immutable staged files, refetches and validates server
records, then conditionally updates the pointer. Cleanup begins only after the pointer references the
new generation. CloudKit errors map to safe domain categories with opaque operation IDs. Development
and production schema promotion must be documented and reproducible.

## Test Plan

- Unit: error mapping, pointer preconditions, upload plans, and cleanup decisions.
- Integration: deterministic fake CloudKit store with failure and termination at every phase.
- Acceptance: development-container smoke checklist; CI must not require a personal iCloud account.

## Acceptance Criteria

- Any pre-publication failure preserves the previous current generation.
- Interrupted publication retries idempotently or replaces its abandoned generation safely.
- Successful publication retains only the new validated snapshot at steady state.
- No CloudKit type leaks into domain, coordinator, or Settings presentation code.

## Rollout Notes

Keep publication inaccessible to owners until scheduling and status controls ship.

## Implementation Notes

- `CloudBackupPublisher` creates a deterministic upload plan from a validated snapshot, uploads into
  a non-current generation, verifies remote metadata and every payload checksum, then conditionally
  advances the current pointer.
- `CloudKitBackupStore` is the only CloudKit-dependent adapter. Application publication protocols,
  plans, results, and error categories remain CloudKit-free.
- Pointer publication and generation deletion use server-record preconditions. Cleanup can delete a
  candidate only while atomically proving that an unchanged pointer does not reference it.
- Interrupted attempts are replaced safely on retry. Post-publication cleanup failures retain the
  valid new pointer and report pending cleanup.
- `docs/cloudkit-backup-operations.md` records the private schema, development-to-production process,
  signing requirements, and manual development-container smoke checklist. CI remains independent of
  personal iCloud accounts.
- The app target declares the CloudKit container entitlement, but publication remains dormant until
  the scheduling and Settings slices activate it.

## Wiki Decision

No wiki change. RFC-0102 adds dormant CloudKit publication infrastructure and an engineering
runbook; owner-facing backup behavior and guidance arrive with later Settings and lifecycle slices.
