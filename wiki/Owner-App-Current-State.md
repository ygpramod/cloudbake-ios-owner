# Owner App Current State

This page describes what the CloudBake owner app has today. It is a browsable operating summary,
not a replacement for the source RFCs, ADRs, tests, or code.

## Product Shape

CloudBake owner is a native SwiftUI app for iPhone and iPad. The app is owner-only, local-first, and
does not require a backend for the workflows that exist today.

Primary destinations exist for:

1. Dashboard,
2. Orders,
3. Inventory,
4. Recipes,
5. Designs,
6. Customers,
7. Settings.

Inventory is the first real working domain. Other destinations exist as navigation surfaces and are
ready for future slices.

## Persistence

The app uses local SQLite storage through GRDB.

Current persistence characteristics:

1. database access is behind repository boundaries,
2. schema changes are introduced through explicit migrations,
3. owner workflows remain available without network access,
4. sync, iCloud, and backend integration are future work.

## Core Data Model

The domain model has foundations for:

1. inventory items,
2. inventory transactions,
3. recipes,
4. orders,
5. customers,
6. cake designs,
7. pricing,
8. reminders.

Only the inventory-related workflows are active in the UI today.

## Inventory State

The owner can manage active inventory items.

Current inventory behavior:

1. view inventory items from local storage,
2. add inventory items with name, unit, current quantity, and minimum quantity,
3. see current quantity and minimum quantity in the inventory list,
4. see low-stock state when current quantity is below minimum quantity,
5. receive a warning before adding an item with the same or similar name,
6. edit active inventory item details,
7. archive active inventory items,
8. view archived inventory items,
9. restore archived inventory items,
10. add stock to an active inventory item,
11. manually record stock usage for an active inventory item.

Supported units currently include the app's inventory unit enum. Product requirements emphasize kg,
ml, grams, teaspoons, tablespoons, and cups as important owner units.

## Inventory Transactions

Inventory stock changes are stored as transaction records.

Current transaction behavior:

1. stock adjustment creates an `adjustment` transaction,
2. stock consumption creates a `consumption` transaction,
3. transaction quantities are stored as positive numbers,
4. transaction kind carries the business meaning,
5. optional notes can be stored with stock changes,
6. transaction history UI is not implemented yet.

## Dashboard State

The dashboard shows low-inventory information and provides a quick route back to inventory.

The dashboard is intentionally lightweight until more operational domains exist.

## Testing And CI

The repo uses split test lanes:

1. `CloudBakeOwnerUnitIntegration` for fast local unit and integration feedback,
2. `CloudBakeOwnerAcceptance` for XCUITest owner workflow coverage,
3. GitHub Actions for pull-request safety checks.

For local development, run unit/integration tests for changed logic and only the impacted
acceptance tests for the changed workflow. CI remains the full safety net.

## Current Future Gaps

These are known gaps, not bugs in the current slices:

1. recipe storage and recipe-driven inventory reduction,
2. cake design photo storage,
3. customer profiles, allergies, likes, dislikes, and preferences,
4. order calendar and delivery reminders,
5. pricing calculator,
6. transaction history UI,
7. iCloud or backend sync,
8. consumer-facing cake browsing or customization,
9. backend API integration,
10. AI-assisted cake design suggestions.

## Source References

Detailed source truth lives in:

1. `README.md`,
2. `docs/engineering-guardrails.md`,
3. `docs/adr/`,
4. `docs/rfc/slices/`,
5. app and test source files.

Update this page when a slice changes what the owner app currently has or how the app should be
understood operationally.
