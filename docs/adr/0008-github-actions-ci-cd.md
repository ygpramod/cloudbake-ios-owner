# ADR-0008: Use GitHub Actions for CI/CD

## Status

Accepted

## Context

The owner app repository needs automated quality gates from the first implementation slice.

## Decision

Use GitHub Actions for CI/CD.

Pull requests should build the app and run the available unit, integration, and UI tests.

## Consequences

CI integrates directly with GitHub pull requests and branch protection. macOS runner availability and cost should be watched as the test suite grows.
