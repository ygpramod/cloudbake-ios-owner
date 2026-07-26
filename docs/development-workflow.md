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

Run the repository contracts before handoff:

```sh
./scripts/check_acceptance_test_registration.py

SWIFT_FORMAT_BASE_SHA="$(git merge-base origin/main HEAD)" \
  ./scripts/lint_swift.sh

./scripts/verify_release_composition.sh
```

Keep the acceptance lane focused on critical owner journeys. When a slice adds detailed business
behavior, prefer unit or integration tests for the detailed cases and update an existing journey only
when the owner-facing workflow changes.

GitHub Actions time-boxes the unit/integration job and feature-sharded acceptance UI jobs so stuck
simulator automation fails clearly instead of blocking a pull request indefinitely. Acceptance UI
tests run in eight feature shards: `core-recipes`, `settings`, `orders-core`, `order-workflows`,
`order-links`, `customers`, `inventory`, and `designs`.
Each pull request or branch has only one active CI generation. Pushing a newer commit automatically
cancels any superseded workflow run for that same pull request or branch so its macOS runners are
released for the new head commit.
CI prefers known iPhone simulator names when available, falls back to the first available iPhone,
and uploads the Xcode result bundle for failed test jobs.

See [`testing-and-ci.md`](testing-and-ci.md) for selector ownership, targeted commands, the
changed-file formatting contract, and Release-composition verification.

## Main Branch Protection

`main` should be protected in GitHub with these rules:

- Require a pull request before merging.
- Require at least one approval.
- Require review from code owners.
- Require status checks to pass before merging once CI exists.
- Block force pushes.
- Block branch deletion.

## App Store Releases

After a release candidate is reviewed, green, and merged, follow
[`app-store-release-runbook.md`](app-store-release-runbook.md). It records the archive and upload
commands, App Store Connect metadata, TestFlight setup, real-device smoke test, final submission
sequence, release evidence, and complications observed during the first CloudBake release.
