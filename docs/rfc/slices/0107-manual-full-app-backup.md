# Slice RFC-0107: Manual Full-App Backup

## Status

Implemented.

## Parent Decisions

- Foundation ADR-0010: Use CloudKit For Owner App Disaster Recovery
- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0101: Cloud Backup Snapshot Foundation

## Goal

Let the owner save a complete, validated recovery package without requiring CloudKit or a paid Apple
Developer Program membership.

## Scope

1. Add a collapsed-by-default **Backup** section in Settings.
2. Create a complete snapshot containing the database, custom logo, app-managed images, and
   lightweight recovery copies of referenced Photos-library images.
3. Export the snapshot as one opaque `.cloudbakebackup` package through the system Files picker.
4. Record and show the last successful manual export date.
5. Enable a weekly local reminder by default, allow it to be disabled, and reset its due date only
   after a successful export.
6. Keep **Data Management** collapsed by default as already decided by RFC-0104.

## Out Of Scope

- Package restore, automatic scheduling, CloudKit upload, history, merge, and selective export.
  Full validated restore follows in RFC-0108.

## Design

Reuse the RFC-0101 snapshot contract and validation. Compress the immutable staging directory into
one regular-file custom archive without loading every photo into memory. The Files picker lets
the owner choose iCloud Drive, another file provider, or local storage. A successful picker result is
the publication boundary for last-backup metadata and reminder rescheduling. Cancellation and export
failure do not claim success. Reminder scheduling is best effort and never blocks normal app use.

## Test Plan

- Unit: preparation metadata, safe filename, reminder defaults, seven-day scheduling, disable, reset,
  overdue behavior, and export success/failure state.
- Integration: RFC-0101 package tests prove database and referenced asset capture and integrity.
- Acceptance: Backup and Data Management start collapsed; expanding Backup exposes status, reminder
  toggle, and the system export picker.

## Acceptance Criteria

- A successful export is a validated full-app package rather than a partial CSV.
- The owner chooses the destination and can save to iCloud Drive without CloudKit capability.
- Failed or cancelled export cannot update last-success state.
- The weekly reminder is on by default, can be disabled, and is reset by successful export.
- No private owner data appears in the exported filename or notification text.

## Rollout Notes

Keep CloudKit RFC-0102 paused at its Apple-program activation gate. The manual package format must
remain compatible with the future CloudKit transport and RFC-0108 restore.

## Implementation Notes

- `ManualBackupService` reuses the RFC-0101 consistent snapshot and validation boundary, then streams
  the immutable directory into one compressed `.cloudbakebackup` archive using ZIPFoundation.
- A URL-based `UIDocumentPickerViewController` copies the archive without loading it into memory. It
  replaces SwiftUI's transferable exporter, which crashes while assigning filenames to this custom
  archive on the supported simulator runtime.
- The last-success boundary is the document picker's successful destination callback, not snapshot
  preparation. Cancellation leaves last-success metadata unchanged.
- `ManualBackupReminderScheduler` stores one durable due date, schedules overdue reminders promptly,
  resets to seven days only after successful export, and removes the request when disabled.
- Settings presents Backup and Data Management as collapsed disclosure sections and keeps all
  backup creation behind an explicit summary and confirmation.
- RFC-0108 remains required before CloudBake can restore this archive inside the app.

## Wiki Changes

- `wiki/Owner-Workflows.md` documents creation, destination choice, reminder behavior, privacy, and
  the pending restore boundary.
- `wiki/Current-App-Capabilities.md` records full-app manual export.
- `wiki/Business-Concepts.md` defines the package as private disaster-recovery data.
