# Slice RFC-0104: CloudKit Full Restore

## Status

Approved.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0103: Cloud Backup Settings And Status

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

