# Slice RFC-0003: Core Data Model

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Introduce the first minimal CloudBake domain models and local database tables for the owner app.

This slice creates just enough structure for later feature slices to build inventory, recipes, orders, customers, pricing, photos, and design suggestions without redefining the core concepts.

## Scope

- Add minimal domain models for the core concepts.
- Add database migrations for the initial core tables.
- Add repository interfaces for core concepts.
- Add simple GRDB-backed repository implementations where needed to prove the model.
- Add fixture-style test data in integration tests.
- Add tests for migrations, inserts, fetches, identifiers, and timestamps.

## Out of Scope

- Full CRUD screens.
- Business workflows such as inventory reservation, inventory consumption, recipe scaling, pricing calculation, reminders, or design suggestions.
- Complex validation beyond basic model integrity.
- Backend sync fields beyond stable IDs and timestamps needed for future readiness.

## Requirements

- Base entities must use stable identifiers.
- Base entities must include creation and update timestamps.
- Tables must be minimal but extensible through later migrations.
- Repository interfaces must avoid exposing GRDB details.
- Tests must prove the database can store and retrieve each base concept.

## Base Domain Model

This slice introduces minimal versions of:

- `InventoryItem`
- `Recipe`
- `RecipeComponent`
- `RecipeIngredient`
- `CakeDesign`
- `Customer`
- `Order`
- `InventoryTransaction`
- `PricingRule`

## Design

### Model Boundaries

Models represent CloudBake concepts without embedding future workflow logic too early. For example, `Order` has a status field, but inventory reservation behavior belongs to a later slice.

### Persistence

The slice adds a second GRDB migration for core tables. The repository implementation saves and fetches one record at a time so later slices can expand query shapes deliberately.

### Future Sync Readiness

The model preserves future sync readiness through stable identifiers and timestamps, but this slice does not implement sync.

## Test Plan

- Unit tests:
  - Verify core enum raw values used for persistence.

- Integration tests:
  - Run all migrations from a fresh database.
  - Insert and fetch one record for each base entity.
  - Verify stable IDs and timestamps persist.
  - Verify repository interfaces can be exercised without SwiftUI.

- Acceptance tests:
  - Existing app shell acceptance tests still pass.

## Acceptance Criteria

- Initial core domain models exist.
- Initial core database tables exist.
- Migrations run from a fresh database.
- Repository interfaces exist for core concepts.
- Tests cover basic persistence for each base concept.
- The app shell still builds and launches.

## Rollout Notes

This slice creates structure, not feature behavior. Feature-specific RFCs should add fields and behavior only when needed by their workflows.
