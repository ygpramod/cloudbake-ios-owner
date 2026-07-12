# Slice RFC-0103: Cloud Backup Scheduling And Connectivity

## Status

Approved.

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
