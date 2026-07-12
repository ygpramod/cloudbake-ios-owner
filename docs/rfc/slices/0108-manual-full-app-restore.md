# Slice RFC-0108: Manual Full-App Restore

## Status

Proposed.

## Parent Decisions

- Slice RFC-0107: Manual Full-App Backup
- Slice RFC-0105: CloudKit Full Restore

## Goal

Restore one owner-selected `.cloudbakebackup` package without risking the installation it replaces.

## Scope

Inspect compatibility, date, size, and integrity; require confirmation; create a rollback snapshot;
stage and migrate the database; handle broken assets; atomically activate; verify; recover interrupted
activation at startup; and roll back every failed activation.

## Out Of Scope

Selective restore, merge, backup history, and CloudKit transport.

## Acceptance Criteria

- Populated local state is never replaced without explicit confirmation.
- Corrupt or incompatible packages are rejected before maintenance begins.
- No failure or interruption leaves a mixed database and asset state.
- A successful restore reloads the app with the complete selected package.

