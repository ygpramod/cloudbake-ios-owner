# ADR-0007: Require Unit, Integration, and Acceptance Tests

## Status

Accepted

## Context

CloudBake manages correctness-sensitive workflows such as inventory, pricing, orders, reminders, and recipes. Tests are mandatory from the first implementation slice.

## Decision

Use XCTest for iOS unit and integration tests and XCUITest for acceptance/UI tests.

CI runs unit/integration tests and acceptance/UI tests as separate jobs with focused Xcode schemes. Local development should use the unit/integration lane for fast feedback and the full scheme test or both CI jobs before merging implementation work.

Swift Testing may be introduced later for pure Swift domain tests if it improves readability without weakening CI or tooling support.

## Consequences

Implementation slices must include automated tests as part of the definition of done.

Separating test lanes makes failures easier to diagnose and avoids requiring the slower UI acceptance suite for every local edit.
