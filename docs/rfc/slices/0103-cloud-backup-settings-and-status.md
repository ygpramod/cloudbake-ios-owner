# Slice RFC-0103: Cloud Backup Settings And Status

## Status

Approved.

## Parent Decisions

- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0102: Cloud Backup Scheduling And Connectivity

## Goal

Give the owner understandable backup controls, status, and manual-backup behavior in Settings.

## Scope

1. Add collapsed-by-default **Backup** and **Data Management** disclosure sections.
2. Show enabled state, iCloud availability, last success, active/latest status, failure guidance, and
   estimated transfer size.
3. Add enable/disable and **Back Up Now** controls.
4. Add cellular confirmation and independently configurable backup notifications.
5. Use existing CloudBake Settings, popup, loading, and error styles.

## Out Of Scope

- Restore execution and permanent cloud deletion; their entries remain unavailable until implemented.

## Design

Settings observes a presentation model derived from coordinator state and durable local metadata.
SwiftUI contains no CloudKit or scheduling policy. Disabling backup stops future publication but
retains the latest cloud snapshot. Enabling schedules eligible work without blocking Settings. Manual
cellular upload displays estimated size and requires explicit confirmation. Status and notifications
must not expose customer, recipe, cost, or photo content.

## Test Plan

- Unit: status copy, safe error mapping, enabled and notification preferences.
- Integration: preference persistence and coordinator commands.
- Acceptance: collapsed defaults, expansion, enable/disable, Back Up Now, cellular confirmation,
  unavailable state, retry, and notification toggle. Assign tests to the Settings/data CI shard.

## Acceptance Criteria

- The owner can see whether backup is enabled and when it last succeeded.
- Disabling backup cannot delete the retained snapshot.
- Cellular upload cannot begin without informed confirmation.
- Dynamic Type, VoiceOver, and app visual patterns remain supported.

## Rollout Notes

Update repo-local wiki owner workflows and privacy documentation in the implementation PR.

