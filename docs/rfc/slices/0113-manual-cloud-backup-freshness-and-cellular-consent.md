# Slice RFC-0113: Manual Cloud Backup Freshness And Cellular Consent

## Status

Implemented.

## Parent Decisions

- Foundation RFC-0002: CloudKit Disaster Recovery
- Slice RFC-0103: Cloud Backup Scheduling And Connectivity
- Slice RFC-0104: Cloud Backup Settings And Status

## Goal

Make **Back Up Now** a dependable owner command rather than a change-sensitive scheduling hint.

## Scope

1. Create a fresh complete snapshot for every manual backup request, even when app data has not
   changed since the previous successful backup.
2. Publish that new generation immediately on Wi-Fi, subject to the existing account, power, and
   working-storage safety gates.
3. Require a new size-aware confirmation for every manual request made on cellular data.
4. Keep cellular approval scoped to its exact proposal and snapshot generation.
5. Leave automatic backup eligibility and Wi-Fi-only behavior unchanged.

## Design

The manual path intentionally bypasses nightly due-date and content-change decisions. Each accepted
request asks `AppSnapshotService` for a new UUID-backed generation and passes that package to atomic
CloudKit publication. A cellular proposal binds the generated package, a one-time proposal ID, and
the displayed byte estimate. Successful approval is consumed by that attempt and is never stored as
a general cellular preference.

Manual backup still respects explicit cloud-backup disablement and the established iCloud account,
power, storage, and in-flight-operation safety gates. Those protections are not evidence that the
request was skipped because content was unchanged.

## Test Plan

- Unit: two unchanged Wi-Fi requests create and publish two distinct generations.
- Unit: approving one cellular proposal does not authorize the next manual request.
- Existing unit and acceptance coverage: account authorization, size binding, cancellation,
  automatic Wi-Fi enforcement, and Settings presentation.

## Acceptance Criteria

- Tapping **Back Up Now** after a successful backup creates and publishes another fresh generation.
- A cellular tap always presents the current estimated size before any publication begins.
- Confirming cellular use publishes only the displayed proposal.
- A later cellular tap asks again.
- Automatic backup remains Wi-Fi-only.

## Wiki Decision

Updated the owner workflow and current capability source to make manual freshness and per-attempt
cellular consent explicit.
