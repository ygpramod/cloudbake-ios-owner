# Slice RFC-0105: CloudKit Full Restore

## Status

Implemented.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0104: Cloud Backup Settings And Status

## Goal

Restore one complete, validated cloud snapshot without risking the local installation it replaces.

## Scope

1. Inspect backup date, size, integrity, and compatibility before download.
2. Offer **Restore** or **Start Fresh** on an empty installation without automatic restore.
3. Require destructive confirmation before replacing populated local state.
4. Require size-aware confirmation for cellular restore.
5. Create a local rollback snapshot, validate and migrate in staging, handle broken assets, atomically
   activate, verify, and roll back on any failure.

## Out Of Scope

- Selective restore, merge, historical snapshot choice, and multi-device reconciliation.

## Design

`RestoreCoordinator` owns explicit inspection, confirmation, download, validation, migration,
asset-decision, activation, verification, rollback, and completion states. An app older than the
manifest's minimum compatible version stops and asks the owner to update. Broken assets offer
**Ignore** or **Remove References** with an impact summary. Versioned database and asset roots swap
under a short maintenance boundary. Startup detects and resolves interrupted activation.

## Test Plan

- Unit: compatibility, confirmation policy, broken-asset plans, and state transitions.
- Integration: schema fixtures, corrupt downloads, migration/activation/verification failure,
  interruption, rollback, and empty/populated installations.
- Acceptance: Start Fresh, Wi-Fi restore, cellular approval, replacement confirmation,
  update-required, broken-asset choices, success, and rollback messaging.

## Acceptance Criteria

- Valid compatible state restores the complete database and app-managed assets.
- No failure path leaves mixed old/new active state.
- Populated state cannot be replaced without explicit confirmation and rollback protection.
- Incompatible or corrupt backups are rejected before activation.

## Rollout Notes

Prove restore using a production-like CloudKit snapshot before release; backup is incomplete until
restore is demonstrated.

## Implementation Notes

- `RestoreCoordinator` owns inspection and the ordered owner-confirmation state machine. Backup and
  restore sessions are mutually exclusive.
- `CloudKitBackupStore` inspects the current generation without downloading every asset, then
  downloads into isolated staging and verifies manifest metadata, byte counts, and checksums.
  Only genuinely missing or corrupt photo payloads enter the broken-photo decision; transient
  CloudKit, cancellation, and local storage failures stop restore for a safe retry.
- `LocalRestoreService` migrates and validates the staged database, prepares app-managed assets,
  supports both broken-asset decisions, creates a rollback snapshot for populated installations,
  and replaces the active GRDB contents atomically. Startup recovery rolls back an interrupted
  activation before the app opens its database. The phase-aware activation journal makes recovery
  repeatable at every database and asset replacement boundary.
- Cancellation owns and awaits the active restore operation before releasing the shared
  backup/restore session. Once atomic activation begins, completion or rollback wins over dismissal.
- Successful activation reloads visible app state, refreshes local reminders, and starts a fresh
  backup catch-up after the restore session is released.
- Empty installations offer **Restore Backup** and **Start Fresh**. Populated installations show the
  snapshot date, size, asset count, and integrity before destructive confirmation. Cellular transfer
  and broken assets require their own explicit decisions. A custom-logo-only installation also
  counts as populated owner state and cannot bypass replacement confirmation.
- If rollback cannot be guaranteed, an app-wide recovery barrier prevents further interaction until
  CloudBake is reopened and startup recovery runs. Once a committed journal is durable, cleanup is
  best-effort and cannot incorrectly turn a completed restore into a rollback failure.
- Focused unit, integration, and acceptance coverage proves confirmation ordering, compatibility,
  CloudKit inspection/download, migration, activation rollback, interruption recovery, Start Fresh,
  Wi-Fi restore, cellular approval, broken-asset handling, update-required copy, and rollback copy.
- A production-like device restore remains a release-readiness activity because it requires a real
  current snapshot in the owner's private CloudKit database.
