# Slice RFC-0106: Cloud Backup Account And Deletion Lifecycle

## Status

Implemented.

## Parent Decisions

- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0105: CloudKit Full Restore

## Goal

Handle iCloud account transitions and permanent cloud-backup deletion without exposing or losing
local owner data.

## Scope

1. Detect unavailable and changed iCloud accounts using privacy-safe local identity metadata.
2. Require confirmation before first publication to a newly detected account.
3. Add **Delete Cloud Backup** under collapsed Data Management.
4. Delete current and abandoned CloudKit generations after destructive confirmation.
5. Retain local data and leave backup disabled after successful deletion.

## Out Of Scope

- Moving backups between Apple IDs, shared accounts, CloudBake authentication, and non-Apple account recovery.

## Design

Store only an opaque account fingerprint suitable for change detection. Account loss or change never
edits local data, and local data is never silently uploaded to a new account. Deletion is an
idempotent, verified cloud-store operation covering the pointer, manifest, database, assets, and
abandoned generations. It is distinct from disabling backup, which retains the latest snapshot.

## Test Plan

- Unit: unavailable/same/changed-account policy, first-publication confirmation, and deletion states.
- Integration: interrupted and retried deletion, orphan cleanup, and local-state preservation.
- Acceptance: unavailable account, changed account, cancel/confirm first backup, cancel/confirm
  deletion, deletion failure, and successful local-data retention.

## Acceptance Criteria

- Changing Apple IDs cannot silently disclose local CloudBake data.
- Permanent deletion removes recoverable cloud content while preserving all local state.
- Backup remains disabled after deletion until explicitly enabled.
- Failure and retry states remain truthful and recoverable.

## Rollout Notes

Update wiki privacy and owner-workflow documentation before release.

## Implementation Notes

- CloudBake derives a SHA-256 account fingerprint from the private CloudKit user record and
  container identifier. It never persists the raw record name or Apple ID.
- First publication to an unrecognized account requires confirmation. Publication revalidates the
  confirmed fingerprint immediately before CloudKit writes, so an account change cannot reuse a
  stale approval.
- Permanent deletion removes the dedicated private CloudKit backup zone, which includes the
  pointer, current generation, abandoned generations, database, manifest, and assets. The local
  backup preference is disabled before remote deletion begins. A missing zone is treated as an
  already-complete deletion, and CloudBake verifies the zone is absent before reporting success.
- Once destructive deletion starts, backup remains disabled even if remote completion cannot be
  verified because of interruption or network failure. The owner can safely retry the idempotent
  deletion or explicitly enable backup to publish again.
- Local database and photo storage are outside the cloud deletion boundary and remain unchanged.
