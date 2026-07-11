# Slice RFC-0001: Owner App Shell

## Status

Draft

## Parent RFC

- `ygpramod/CloudBake` `requirements.md`

## Goal

Create the smallest useful owner app foundation: a SwiftUI iPhone app that builds, launches, shows the primary navigation shell, and has basic CI/test coverage.

## Scope

- Create the initial owner app project structure.
- Configure one SwiftUI app target for iPhone.
- Add a dashboard as the launch screen.
- Add primary navigation destinations for core product areas.
- Add placeholder screens only.
- Add XCTest and XCUITest targets.
- Add GitHub Actions CI that builds the app and runs initial tests.
- Add repo-local engineering guardrails and ADRs required for owner app development.

## Out of Scope

- SQLite/GRDB setup.
- Database migrations.
- Domain models and repositories.
- Seed data.
- Inventory, recipe, order, customer, pricing, reminder, or photo behavior.
- Backend integration.
- iCloud or backend sync.
- Polished visual design.

## Requirements

- The app must build as a native Swift/SwiftUI iPhone app.
- The app must launch to a dashboard or primary shell.
- The app must expose navigation destinations for Dashboard, Orders, Inventory, Recipes, Designs, Customers, and Settings.
- Tests must exist from this slice.
- CI must fail if the app does not build or launch tests fail.
- Repo-local guardrails must document SwiftUI code quality, accessibility, testing, privacy, and future observability expectations.

## Acceptance Criteria

- The owner app builds for iPhone.
- The app launches successfully.
- Primary navigation exists for Dashboard, Orders, Inventory, Recipes, Designs, Customers, and Settings.
- Placeholder screens exist for each primary destination.
- XCUITest covers app launch and primary navigation.
- GitHub Actions runs build and initial tests on pull requests.
