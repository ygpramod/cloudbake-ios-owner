# ADR-0007: Require Unit, Integration, and Acceptance Tests

## Status

Accepted

## Context

CloudBake manages correctness-sensitive workflows such as inventory, pricing, orders, reminders, and recipes. Tests are mandatory from the first implementation slice.

## Decision

Use XCTest for iOS unit and integration tests and XCUITest for acceptance/UI tests.

Swift Testing may be introduced later for pure Swift domain tests if it improves readability without weakening CI or tooling support.

## Consequences

Implementation slices must include automated tests as part of the definition of done.
