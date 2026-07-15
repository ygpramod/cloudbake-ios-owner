# Slice RFC-0101: Cloud Backup Snapshot Foundation

## Status

Implemented.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery

## Goal

Create and validate a consistent, versioned local recovery package without uploading data or changing
CloudBake's normal local-first behavior.

## Scope

1. Define the backup manifest, compatibility, database snapshot, asset inventory, checksum, and size models.
2. Add snapshot creation and validation boundaries that do not depend on CloudKit.
3. Capture GRDB consistently while the owner continues using the app.
4. Stage every lightweight photo referenced by the captured database. Materialize legacy/current
   `photos://` references into canonical app-managed recovery paths rather than retaining an external
   reference that may not survive device loss.
5. Clean abandoned staging packages safely.

## Out Of Scope

- CloudKit capability and upload.
- Scheduling, Settings, notifications, or restore activation.
- Multi-device synchronization.

## Design

Add pure manifest models plus `AppSnapshotCreating` and `AppSnapshotValidating` protocols. The GRDB
implementation uses SQLite's supported online backup mechanism rather than copying live database
files. Asset enumeration is derived from the captured database and copied to an immutable generation
directory. PhotoKit assets are resized into lightweight JPEG recovery payloads, and the staged
database copy is rewritten to canonical app-managed recovery paths. The manifest records format
version, database schema version, minimum compatible app
version, generation ID, timestamp, database and asset checksums, individual sizes, and total size.
Hashing and file work run outside the main actor. Filenames and logs contain no private domain data.

## Test Plan

- Unit: manifest encoding, compatibility, deterministic checksums, size totals, and safe identifiers.
- Integration: concurrent database writes, referenced/missing/corrupt assets, cleanup, and migrated schemas.
- Acceptance: not applicable because this slice has no owner-facing behavior.

## Acceptance Criteria

- A validated package represents one database point in time and all referenced app-managed assets.
- Post-capture edits cannot create a mixed snapshot.
- Missing or modified files fail validation.
- Existing local workflows remain unchanged.

## Rollout Notes

Ship dormant foundations only. Do not request CloudKit access or schedule background work in this slice.

## Implementation Notes

- `AppSnapshotService` uses GRDB's online backup API and runs as an actor outside the main actor.
- Captured database references drive asset staging. Existing `photos://` assets are materialized as
  lightweight recovery payloads and only the staged database copy is rewritten to their canonical
  app-managed restore destinations; live local-first state remains untouched.
- A database-capture timestamp plus source modification metadata rejects assets changed after the
  database point in time, while before/after checksums reject changes during file copying.
- The app-managed custom logo is included when present so branding survives eventual full restore.
- Staged asset filenames are opaque hashes. Original relative paths remain only inside the manifest
  needed to reconstruct app-managed storage.
- The package exposes the manifest decoded from the exact persisted JSON bytes. This keeps lossy
  date serialization, including fractional-second normalization, identical between package
  validation and the CloudKit publication plan.
- Packages remain dormant local artifacts in this slice; CloudKit publication begins in RFC-0102.

## Wiki Decision

No wiki change. RFC-0101 adds dormant recovery infrastructure with no owner-visible workflow;
owner-facing backup guidance will be documented with the Settings and status slice.
