# Testing And CI

CloudBake uses one fast unit/integration lane and feature-sharded XCUITest acceptance lanes. Local
development should prove the smallest relevant behavior; GitHub Actions remains the complete merge
safety net.

## Repository Checks

Run these dependency-free checks before tests:

```sh
./scripts/check_acceptance_test_registration.py

SWIFT_FORMAT_BASE_SHA="$(git merge-base origin/main HEAD)" \
  ./scripts/lint_swift.sh
```

The acceptance-registration check discovers every `func test…` declaration in
`CloudBakeOwnerUITests/*.swift`, verifies every Swift source belongs to the
`CloudBakeOwnerUITests` Xcode target, and requires each matching selector to appear exactly once in
`.github/workflows/ci.yml`. It fails for missing target membership, missing files, duplicate,
malformed, or stale selectors.

The formatting check uses the `swift-format` executable bundled with Xcode and checks only Swift
files changed from the supplied base SHA. CI pins Xcode 16.4 so formatter behavior does not drift
with GitHub's default Xcode selection.

## Unit And Integration Lane

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwnerUnitIntegration \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Use an installed iPhone simulator name if `iPhone 17` is unavailable.

## Targeted Acceptance

Run only the owner journeys affected by a focused change:

```sh
xcodebuild test \
  -project CloudBakeOwner.xcodeproj \
  -scheme CloudBakeOwnerAcceptance \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:CloudBakeOwnerUITests/CloudBakeOwnerUITests/testAppLaunchesToDashboard
```

Add more `-only-testing:` arguments when one change affects several journeys. Run the complete
acceptance scheme locally only for broad app-shell, navigation, shared test-support, persistence, or
cross-feature changes.

## Release Composition

```sh
./scripts/verify_release_composition.sh
```

The command builds the generic iOS device `CloudBakeOwner.app` with the Release configuration,
signing disabled, into temporary DerivedData. It then scans the `Release-iphoneos` app bundle and
fails if any Debug-only acceptance environment key is present. Set
`RELEASE_VERIFICATION_DERIVED_DATA` only when the build artifacts need to be retained for diagnosis.

This check proves build composition; a source-code search is not an equivalent replacement.

## GitHub Actions

The existing unit/integration job runs, in order:

1. acceptance-selector registration,
2. changed-file Swift formatting,
3. Release-composition verification,
4. unit and integration tests.

Acceptance journeys run in eight feature shards:

1. `core-recipes`,
2. `settings`,
3. `orders-core`,
4. `order-workflows`,
5. `order-links`,
6. `customers`,
7. `inventory`,
8. `designs`.

GitHub starts only the jobs allowed by the account's runner concurrency. Matrix entries beyond that
limit remain queued and start as runners become available. A newer push automatically cancels the
older workflow generation for the same pull request or branch.

Every required job must be green for the exact reviewed head. Failed test jobs upload their
`.xcresult` bundle. Diagnose the failure from that evidence and the Actions log; do not normalize a
recurring failure with retries.
