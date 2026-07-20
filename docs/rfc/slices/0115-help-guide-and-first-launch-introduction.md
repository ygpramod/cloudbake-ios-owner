# Slice RFC-0115: Help Guide And First-Launch Introduction

## Status

Accepted.

## Goal

Help a new owner understand CloudBake without interrupting normal bakery work, and keep complete
offline instructions available from Settings.

## Scope

1. Show a five-page introduction only on the first normal installation.
2. Use **Next**, **Skip**, page indicators, and a final **Get Started** action; do not navigate into
   live feature screens during the introduction.
3. Add **Help & Guide** under Settings with offline explanations and practical steps for CloudBake's
   owner workflows.
4. Allow the introduction to be replayed from Help & Guide without changing first-install state.
5. Keep automated-test launches deterministic and add an explicit fixture for introduction coverage.

## Design

The introduction explains Home, Orders, Inventory, the bakery library, and backup using concise copy
and system imagery. Completion is stored as an app-only preference. The guide is bundled, searchable
by normal screen reading, and organized as short feature topics with actionable steps. No owner data
leaves the device and no network connection is required.

## Test Plan

- Unit: introduction ordering and first-install presentation policy.
- Acceptance: first-install Next/Skip flow and Settings access to Help & Guide/replay.
- Existing UI-test launches bypass automatic introduction unless the dedicated fixture is enabled.

## Acceptance Criteria

- A new production installation sees the introduction once.
- Skip and Get Started both dismiss it and prevent automatic redisplay.
- Settings always exposes Help & Guide and can replay the introduction.
- Every currently shipped owner domain has concise offline help.
- Existing launch, restore, and navigation automation remains deterministic.

## Wiki Decision

Update repo-local wiki capabilities because owner-visible help and first-launch behavior change.
