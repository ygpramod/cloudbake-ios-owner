# Slice RFC-0120: Isolate Acceptance Fixtures From Release Composition

## Status

Implemented in the owner app.

## Goal

Keep deterministic XCUITest setup available to Debug acceptance builds without allowing test
environment flags, in-memory database selection, or fixture seeding to participate in App Store
Release composition.

## Requirements

1. Acceptance runtime detection and fixture selection live under `AcceptanceTestSupport`.
2. The production database container opens the durable on-device database unless a Debug-only
   acceptance factory explicitly supplies an in-memory database.
3. Database seed routines compile only in Debug builds.
4. App and root-view composition consume typed acceptance configuration instead of reading test
   environment keys directly.
5. A fixture-specific environment value cannot activate fixtures unless the explicit in-memory
   acceptance flag is also present.
6. Existing acceptance journeys and fixture data remain unchanged.
7. The built Release app contains no `CLOUDBAKE_TEST`, `CLOUDBAKE_SEED`,
   `CLOUDBAKE_USE_IN_MEMORY_DATABASE`, or `CLOUDBAKE_INITIAL_DESTINATION` environment keys.

## Validation

1. Unit coverage proves acceptance mode requires the explicit in-memory flag.
2. Database migration tests remain green.
3. Dashboard launch and seeded completed-order acceptance journeys remain green.
4. A Release build succeeds and a binary scan proves acceptance environment keys are absent.

## Wiki Decision

No wiki change is required. This slice changes build composition and test architecture only; it
does not change an owner-visible workflow or product capability.
