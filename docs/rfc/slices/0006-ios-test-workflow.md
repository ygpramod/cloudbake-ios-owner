# RFC-0006: iOS Test Workflow Split

## Status

Accepted

## Authority and Scope

This slice applies to the CloudBake owner iOS repository test workflow, local developer commands, and GitHub Actions CI jobs.

It does not change product behavior, production code, persistence, or acceptance-test coverage expectations.

## Requirements Summary

- Provide a fast local test lane for day-to-day development feedback.
- Preserve acceptance/UI tests as required verification for implementation pull requests.
- Make CI failures easier to diagnose by separating unit/integration tests from feature-sharded
  acceptance UI tests.
- Document the expected local commands so contributors do not need to rediscover them.

## Design

CI runs two lanes:

- `Unit and Integration Tests` runs the `CloudBakeOwnerUnitIntegration` scheme.
- `Acceptance UI Tests (<feature>)` runs the `CloudBakeOwnerAcceptance` scheme with feature-specific
  `-only-testing` filters for core/recipes/customers, order core workflows, order link workflows,
  and inventory.

Both CI lanes are time-boxed. Acceptance shards run in parallel and use `fail-fast: false`, so a
failure in one feature does not hide another feature's failure. This keeps hosted-runner simulator
hangs visible as CI failures instead of leaving pull requests permanently pending.

Core smoke tests, recipe tests, and customer tests share one acceptance shard. Orders are split into
core workflow and link workflow shards because the order suite is the slowest owner-facing area. CI
runs at most five macOS jobs in parallel: one unit/integration job and four acceptance jobs. This
matches the current macOS runner concurrency limit while preserving acceptance coverage.

CI prefers a known modern iPhone simulator when the runner provides one, then falls back to the
first available iPhone. Failed CI test jobs upload their `.xcresult` bundle as a GitHub Actions
artifact so the failing test, screenshot, and simulator logs can be inspected without guessing from
the short pull request status.

Local development should usually start with the unit/integration lane:

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwnerUnitIntegration \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Focused schemes control which test bundles Xcode builds. CI then applies `-only-testing` filters
inside the acceptance scheme to split the growing UI suite by feature area.

Implementation pull requests still require acceptance confidence through either targeted local
acceptance tests for impacted workflows plus passing CI, or a full local scheme run when broader
risk justifies it.

## Non-Functional Requirements

- The split must not weaken the definition of done for implementation slices.
- The workflow must stay compatible with GitHub-hosted macOS runners.
- Simulator selection should remain dynamic in CI while preferring known iPhone device names for consistency.
- CI jobs should fail clearly when a simulator or UI automation run is stuck.
- Failed CI test jobs should publish `.xcresult` artifacts for triage.

## Acceptance Criteria

- CI exposes a separate unit/integration job and feature-sharded acceptance UI jobs.
- Documentation explains fast and full test lanes.
- The fast local lane can be run independently of the UI acceptance suite.
- Failed CI test jobs preserve their Xcode result bundles as artifacts.

## Open Questions

- Whether to add reusable shell scripts once test commands become more complex.
- Whether to add screenshot or visual regression testing once UI surface area grows.
