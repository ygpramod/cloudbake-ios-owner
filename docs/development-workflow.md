# Development Workflow

CloudBake owner app changes must go through a branch and pull request before merging into `main`.

## Branches

- `main` is the protected integration branch.
- Feature branches should use the `codex/` prefix unless a different prefix is explicitly requested.
- Each branch should map to one focused RFC slice, ADR update, bug fix, or documentation change.

## Pull Requests

Every pull request should include:

- A short summary.
- Links to related RFCs or ADRs.
- A test plan.
- Notes for any behavior, migration, or follow-up risk.

Pull requests must follow `docs/engineering-guardrails.md`.

Implementation pull requests must include relevant unit, integration, and acceptance test evidence.

## Local Test Lanes

Use the fast lane while developing a slice:

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwnerUnitIntegration \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use the full lane before an implementation PR is ready to merge, or rely on CI passing the
unit/integration job and all feature-sharded acceptance UI jobs:

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Acceptance tests can also be run directly when UI behavior changes:

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwnerAcceptance \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Keep the acceptance lane focused on critical owner journeys. When a slice adds detailed business
behavior, prefer unit or integration tests for the detailed cases and update an existing journey only
when the owner-facing workflow changes.

GitHub Actions time-boxes the unit/integration job and feature-sharded acceptance UI jobs so stuck simulator
automation fails clearly instead of blocking a pull request indefinitely. Acceptance UI tests run in
parallel shards for core navigation, orders, inventory, recipes, and customers.
CI prefers known iPhone simulator names when available, falls back to the first available iPhone,
and uploads the Xcode result bundle for failed test jobs.

## Main Branch Protection

`main` should be protected in GitHub with these rules:

- Require a pull request before merging.
- Require at least one approval.
- Require review from code owners.
- Require status checks to pass before merging once CI exists.
- Block force pushes.
- Block branch deletion.
