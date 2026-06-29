# ADR-0002: Use SQLite and GRDB for Owner App Local Persistence

## Status

Accepted

## Context

CloudBake v1 must work locally on the owner's device. Inventory, recipes, orders, reminders, customers, pricing, and cake design metadata require reliable offline storage. The app must support explicit migrations, deterministic tests, and future sync readiness.

## Decision

Use SQLite through GRDB for local owner app persistence.

Local database access will go through repository interfaces so domain logic and tests are not coupled directly to GRDB. Schema changes will use explicit migrations. Records should use stable identifiers, timestamps, and fields that keep future sync possible.

## Alternatives Considered

- SwiftData: Apple-native and convenient for simple apps, but less explicit for migrations, complex queries, and deterministic persistence testing.
- Core Data: mature and powerful, but heavier and more framework-driven than needed for this project.
- Plain SQLite APIs: explicit, but too low-level for productive Swift development.

## Consequences

The app gains precise control over schema, migrations, and persistence tests. The tradeoff is more implementation code than SwiftData. Repository boundaries are required to keep the app testable and avoid leaking database details into SwiftUI views.

## Related

- RFC: `requirements.md`
- Requirements: Mobile Persistence, Offline and Sync
