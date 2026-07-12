# Slice RFC-0106: Cloud Backup Account And Deletion Lifecycle

## Status

Approved.

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
