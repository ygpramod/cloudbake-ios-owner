# Slice RFC-0103: Cloud Backup Scheduling And Connectivity

## Status

Implemented.

## Parent Decisions

- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0102: CloudKit Atomic Backup Publication

## Goal

Run reliable best-effort nightly backups without making iCloud or networking part of normal app use.

## Scope

1. Register and schedule the iOS background task.
2. Apply Wi-Fi, iCloud-account, power, storage, and in-flight eligibility rules.
3. Start overdue catch-up asynchronously on the next eligible app launch.
4. Coalesce triggers and persist retry-safe scheduling metadata.
5. Support manual cellular backup only after a size-aware approval from presentation.

## Out Of Scope

- Settings layout, notifications, restore, and permanent cloud deletion.

## Design

`BackupCoordinator` consumes injected clock, connectivity, account-status, background-task, snapshot,
and cloud-store protocols. Persist last attempt, last success, overdue state, next eligibility, and
active generation. Treat triggers as intents and coalesce redundant work. Automatic work is always
Wi-Fi-only. Background expiration cancels safely without changing the current cloud snapshot.

## Test Plan

- Unit: nightly eligibility, Wi-Fi enforcement, overdue launch, cellular approval, coalescing,
  expiration, bounded retry, and clock changes.
- Integration: relaunch with persisted overdue and interrupted-operation metadata.
- Acceptance: fixtures prove launch remains responsive and automatic cellular transfer cannot start.

## Acceptance Criteria

- Eligible automatic work publishes at most one necessary snapshot per night.
- Missed background execution catches up without delaying app launch.
- Automatic backup cannot transfer over cellular.
- Termination and expiration preserve the previous successful snapshot.

## Rollout Notes

Report actual execution and last success; never promise an exact nightly clock time.

## Implementation Notes

- `BackupCoordinator` persists enablement, attempts, success, overdue, retry, active-generation, and
  prior upload-size metadata. It coalesces concurrent launch and background intents and uses bounded
  exponential retry after failures or ineligible conditions.
- Automatic backup requires an available iCloud account, Wi-Fi, normal power/thermal conditions,
  and sufficient working storage. The storage gate reserves at least 256 MiB and doubles the larger
  of known app-storage or previous-upload size.
- Every automatic CloudKit operation explicitly disables cellular access. A manual attempt can
  enable cellular only after presentation supplies the exact proposal identifier and displayed byte
  estimate back to the coordinator.
- `BGProcessingTask` registration uses `com.cloudbake.owner.cloud-backup`. Expiration cancels the
  active operation, clears staged state, and leaves the previously published CloudKit pointer intact.
- Launch catch-up starts in an asynchronous utility-priority task. A cellular-only acceptance
  fixture traps if snapshot creation or publication begins, while proving the dashboard remains
  responsive.

## Wiki Decision

Updated `wiki/Current-App-Capabilities.md`, `wiki/Business-Concepts.md`, and
`wiki/Owner-Workflows.md` because best-effort automatic CloudKit backup is now active behavior.
