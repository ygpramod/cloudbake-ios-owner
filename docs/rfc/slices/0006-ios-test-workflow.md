# RFC-0006: iOS Test Workflow Split

## Status

Accepted

## Authority and Scope

This slice applies to the CloudBake owner iOS repository test workflow, local developer commands, and GitHub Actions CI jobs.

It does not change product behavior, production code, persistence, or acceptance-test coverage expectations.

## Requirements Summary

- Provide a fast local test lane for day-to-day development feedback.
- Preserve acceptance/UI tests as required verification for implementation pull requests.
- Make CI failures easier to diagnose by separating unit/integration tests from acceptance UI tests.
- Document the expected local commands so contributors do not need to rediscover them.

## Design

CI runs two jobs:

- `Unit and Integration Tests` runs the `CloudBakeOwnerUnitIntegration` scheme.
- `Acceptance UI Tests` runs the `CloudBakeOwnerAcceptance` scheme.

Both CI jobs are time-boxed. This keeps hosted-runner simulator hangs visible as CI failures instead
of leaving pull requests permanently pending.

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

Focused schemes are used instead of only `-only-testing` filters because scheme-level test membership controls which test bundles Xcode builds.

Implementation pull requests still require acceptance confidence through either the full local scheme test or passing CI jobs.

## Non-Functional Requirements

- The split must not weaken the definition of done for implementation slices.
- The workflow must stay compatible with GitHub-hosted macOS runners.
- Simulator selection should remain dynamic in CI while preferring known iPhone device names for consistency.
- CI jobs should fail clearly when a simulator or UI automation run is stuck.
- Failed CI test jobs should publish `.xcresult` artifacts for triage.

## Acceptance Criteria

- CI exposes separate unit/integration and acceptance UI jobs.
- Documentation explains fast and full test lanes.
- The fast local lane can be run independently of the UI acceptance suite.
- Failed CI test jobs preserve their Xcode result bundles as artifacts.

## Open Questions

- Whether to add reusable shell scripts once test commands become more complex.
- Whether to add screenshot or visual regression testing once UI surface area grows.
