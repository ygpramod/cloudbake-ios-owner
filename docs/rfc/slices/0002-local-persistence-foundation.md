# Slice RFC-0002: Local Persistence Foundation

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`
- `docs/adr/0008-github-actions-ci-cd.md`

## Goal

Add the local persistence foundation for the owner app using SQLite through GRDB, without implementing product-specific workflows.

This slice proves database setup, migrations, test database creation, and repository boundaries before core product tables are expanded.

## Scope

- Add GRDB dependency to the owner app project.
- Add an app database abstraction.
- Add explicit migration infrastructure.
- Add a first minimal migration for a health-check table.
- Add a test database setup that can run migrations from scratch.
- Add repository interface conventions and one small example repository.
- Add persistence integration tests.
- Add CI checks for persistence tests.

## Out of Scope

- Full product data model.
- Inventory, recipe, order, customer, pricing, reminder, or photo tables beyond what is needed to prove migration wiring.
- UI screens that read or write persisted product data.
- Sync, iCloud, or backend integration.

## Requirements

- SQLite/GRDB must be initialized behind a small database container or app database abstraction.
- Schema changes must be represented as explicit migrations.
- Tests must be able to create a temporary or in-memory database and run migrations from scratch.
- Domain and presentation code must not depend directly on GRDB.
- CI must run persistence integration tests.

## Design

### Persistence Boundary

The app exposes `AppDatabase` as the persistence container. Feature code should request repository interfaces from application composition and must not access GRDB directly from SwiftUI views.

### Migrations

Migrations are registered in `AppDatabaseMigrations`. The first migration creates `app_health_checks`, a small table used only to prove migration and repository wiring.

### Testing

Persistence tests create both in-memory and file-backed databases, run all migrations, and verify a minimal read/write path through the repository boundary.

## Test Plan

- Unit tests:
  - Existing destination/navigation tests continue to run.

- Integration tests:
  - Create a fresh in-memory test database.
  - Create a fresh file-backed test database.
  - Run all migrations.
  - Verify the health-check repository read/write path.

- Acceptance tests:
  - App shell UI tests continue to launch and navigate.

## Acceptance Criteria

- GRDB is configured.
- Explicit migration infrastructure exists.
- A fresh test database can run all migrations.
- Persistence code is isolated from SwiftUI views.
- Persistence integration tests run in CI.
- Existing app shell acceptance tests still pass.

## Rollout Notes

This slice establishes the persistence mechanism only. Core CloudBake entities should be added in the next data-model slice.
