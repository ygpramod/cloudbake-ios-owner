# Slice RFC-0119: Business Operations, Reminders, Payments, And Scale

## Status

Proposed. Payment-report presentation and payment-history correction rules require owner
confirmation before implementation.

## Parent RFCs

- `requirements.md`
- `docs/rfc/orders.md`
- `docs/rfc/slices/0053-order-pricing-payment-summary.md`
- `docs/rfc/slices/0056-order-scheduled-reminder-notifications.md`
- `docs/rfc/slices/0098-projected-order-ingredient-demand.md`
- `docs/rfc/slices/0117-order-inventory-shortage-override.md`

## Goal

Make CloudBake dependable as the bakery grows by turning projected ingredient demand into explicit
order reservations, making reminders owner-configurable, following up on unpaid completed orders,
preserving a truthful payment history, and replacing unbounded order reads with purpose-built
queries.

This numbered improvement point ships through one reviewed pull request. Its independent behavior
changes remain separate, buildable commits.

## Scope

1. Persist inventory reservations for accepted orders.
2. Let the owner customize order reminder behavior.
3. Send one daily payment-pending reminder after an order is both completed and due, until paid.
4. Persist payment receipts and expose an owner payment report.
5. Add bounded, indexed order queries for list, dashboard, reminder, customer, design, reservation,
   and reporting workflows.

Out of scope:

1. Online payment collection or payment-provider integration.
2. Accounting, tax, profit-and-loss, invoice, refund, or chargeback workflows.
3. Batch-level stock locking.
4. Multi-user contention or cloud synchronization.
5. Customer-facing notifications.
6. Recurring remote notifications when the app has not refreshed local state.

## Inventory Reservations

### Business Rules

1. Draft and Cancelled orders have no active reservation.
2. Confirmed and In Progress orders reserve their complete scaled recipe and extra-ingredient
   requirements.
3. Moving an order into Confirmed creates or replaces its reservation atomically with the status
   change.
4. Editing the recipe, multiplier, or extra ingredients of a reserved order atomically replaces its
   reservation.
5. Moving a reserved order back to Draft or to Cancelled releases its reservation.
6. Moving a reserved order to Ready or Completed consumes usable inventory through the existing
   one-time order-usage workflow and releases its reservation in the same transaction.
7. A reservation is a full order requirement, not an assignment to a particular stock batch.
   Batch selection remains FEFO at consumption time.
8. Usable availability excludes expired inventory. Available-to-promise is usable quantity minus
   all active reservation requirements for the inventory item.
9. A shortage does not block order confirmation. CloudBake shows the exact affected ingredients
   and asks the owner whether to continue, matching the existing shortage-override posture.
10. Continuing with a shortage preserves the full reservation requirement so every contributing
    order remains visible in shortage planning.
11. Reservation rows are current operational state. They are replaced or deleted rather than kept
    as historical events; inventory consumption transactions and order status remain the audit
    history.
12. Existing Confirmed and In Progress orders are backfilled deterministically from their saved
    recipes, multipliers, and extras during migration or a one-time repair step. Orders whose
    requirements cannot be converted remain usable and surface a repair warning instead of silently
    reserving zero.

### Persistence

Add one `order_inventory_reservations` row per order and inventory item:

- stable id;
- order id;
- inventory item id;
- required quantity in the inventory item's unit;
- unit;
- created and updated timestamps;
- a unique key on order id plus inventory item id.

Index inventory item id for aggregate availability queries. Reservation replacement, order status,
order usage, ingredient costs, inventory transactions, and stock-batch updates must share the
existing database transaction boundary where they occur together.

## Reminder Customization

### Recommended Product Contract

1. The existing default remains three days, two days, one day, and due time.
2. Settings lets the owner choose the default day offsets used for new orders and whether the
   due-time reminder is included.
3. An order can use the current defaults, override them, or disable its order reminders.
4. Editing global defaults never rewrites an existing order's saved reminder plan.
5. Reminder offsets are unique whole days from one through 30 and display in descending lead-time
   order.
6. At least one day offset or the due-time reminder is required when reminders are enabled.
7. Draft, Completed, and Cancelled orders still schedule no operational order reminder.
8. Any saved reminder change immediately replaces pending notification requests for that order.
9. Reminder configuration is stored in the local database so full-app backup and restore preserves
   it.

Add:

- one app-level default reminder configuration row;
- one optional per-order reminder configuration;
- a typed domain value that validates offsets and due-time inclusion.

The owner must confirm whether customization should include both global defaults and per-order
overrides. The recommended contract above assumes both.

## Daily Payment-Pending Reminder

### Business Rules

1. An order becomes eligible only when:
   - status is Completed;
   - its due date/time has passed; and
   - its derived balance due is greater than zero.
2. Readiness alone does not start payment-pending reminders.
3. The reminder fires once per calendar day at the owner-selected reminder time. The initial
   recommendation is 9:00 AM.
4. If the order becomes eligible after today's reminder time, the first reminder is tomorrow.
5. The request repeats daily while eligible and deep-links to the order.
6. Marking the order Paid removes its pending payment reminder immediately.
7. Reducing the balance without paying it in full keeps the reminder active with the updated
   balance.
8. Reopening or cancelling the order removes the payment reminder.
9. Notification authorization denial must not block payment recording or order completion.
10. The in-app Reminders payment section uses the same eligibility rule as notification scheduling.

Persist `completedAt` when an order first enters Completed. Existing completed orders use their
saved `updatedAt` as a conservative migration value. Later payment changes must not alter
`completedAt`.

The owner must confirm whether the payment reminder time is globally customizable. The recommended
contract makes it part of Reminder Settings and defaults to 9:00 AM.

## Payment History And Report

### Required Data Integrity

1. Every newly recorded payment is an immutable receipt with:
   - stable id;
   - order id;
   - positive amount;
   - received-at timestamp;
   - optional owner note;
   - created timestamp.
2. Recording a payment and updating the order's paid total are one atomic operation.
3. For payments recorded after this migration, the order's paid total must reconcile with its
   receipts. The owner-approved legacy migration rule below determines how an existing aggregate
   paid amount participates in that reconciliation.
4. Mark Paid records only the remaining balance as the receipt amount.
5. A partial payment records exactly the newly received amount.
6. Editing quoted price does not rewrite historical receipts.
7. Payments remain private owner data.
8. The report uses bounded date-range queries and never loads the complete order/payment history
   merely to calculate one screen.

### Owner Interview Decision

The owner must choose the report's primary purpose:

1. money received during a selected period;
2. money still outstanding as of today;
3. a full ledger containing both, with summary totals and drill-down.

Recommendation: option 3, opening on the Outstanding filter because it is the actionable view.

The following also require owner confirmation before implementation:

1. whether the report groups by day, week, month, or lets the owner switch;
2. whether a date filter applies to payment received date, order due date, or both through separate
   filters;
3. whether payment method is required;
4. whether correcting a mistaken receipt means a reversible void/correction entry or editable
   history;
5. whether pre-migration aggregate paid amounts should become one clearly labelled opening receipt
   or remain outside the receipt ledger with a migration note;
6. whether CSV export is required in this slice.

Do not implement the report UI or destructive payment correction behavior until these decisions are
recorded here.

## Scale-Oriented Order Queries

### Query Contract

Replace feature-level `fetchOrders()` plus in-memory filtering with repository queries shaped for
their consumers:

1. Active Orders:
   - statuses limited to Draft, Confirmed, In Progress, and Ready;
   - due-date ordering in SQL;
   - an optional bounded due-date range.
2. Completed history:
   - Completed and Cancelled only;
   - reverse due-date ordering;
   - keyset or limit/offset paging with a fixed page size.
3. Home upcoming orders:
   - active orders from the start of today through the existing 30-day window.
4. Reminder scheduling:
   - only reminder-eligible operational orders with future due dates.
5. Payment reminders/report:
   - only completed, due, outstanding orders or receipts in the selected period.
6. Customer history:
   - only orders for the selected customer, ordered and paged.
7. Design/reference workflows:
   - only orders needed by the selected reference relationship.
8. Reservation planning:
   - only orders with active reservation state and no recorded usage.

Keep `fetchOrder(id:)` for direct navigation. Retain `fetchOrders()` only as a test/support or
explicit export boundary; production screens must move to bounded queries in this slice.

### Indexes And Performance

Add or verify indexes for:

- order status plus due date;
- customer id plus due date;
- completed-at plus payment eligibility;
- reservation inventory item id;
- payment received-at;
- payment order id plus received-at.

Persistence tests must verify query ordering, bounds, paging stability, and query-plan index use for
the high-volume paths. A deterministic performance test must seed at least 1,000 orders and 2,000
payment receipts and prove the main list and report queries complete within an agreed local budget.
The test should fail on unbounded feature queries, not depend on wall-clock network or UI timing,
and allow a documented CI multiplier.

## Migration And Backup Safety

1. All new state uses explicit forward-only GRDB migrations.
2. Fresh-database migration coverage must include every new table, column, constraint, and index.
3. Existing orders remain readable before reservation repair completes.
4. No migration deletes or overwrites existing quoted price, paid total, recipe usage, inventory
   transaction, or ingredient-cost history.
5. New database state participates automatically in existing full-app snapshot and CloudKit restore.
6. Reminder requests are reconstructed from restored database state after activation; notification
   requests themselves are never backup data.

## UI And Accessibility

1. Reuse CloudBake screen, card, form, menu, and centered-popup primitives.
2. Reservation availability appears as concise owner information, not another oversized card action.
3. Reminder settings use native data-entry controls within the existing Settings/Data Management
   visual language.
4. Payment report rows remain scannable on supported iPhones and support Dynamic Type.
5. Critical reservation shortages and outstanding balances never rely on color alone.
6. Every critical action and navigation boundary receives a stable accessibility identifier.

## Validation

### Unit

1. Reservation eligibility, replacement, release, full-demand shortage, and unit conversion.
2. Reminder configuration validation and effective-plan selection.
3. Payment-reminder eligibility and next 9:00 AM scheduling with injected clock/calendar.
4. Payment receipt arithmetic, remaining-balance receipt, and correction rules after owner approval.
5. Query input validation and pagination cursor behavior.

### Integration

1. Migration from the current schema and fresh database.
2. Atomic reservation creation/replacement/release and consumption.
3. Atomic payment receipt plus paid-total update.
4. Bounded, ordered, indexed order and payment queries.
5. Backup snapshot and restore validation with new tables/configuration.

### Acceptance

1. Confirm an order and see its reservation/shortage state.
2. Customize or disable an order reminder and verify the saved plan.
3. Open a payment-pending reminder and mark the order Paid.
4. Open the payment report, filter it, and drill into an order after report decisions are approved.
5. Page completed orders without duplicate or missing rows.

Detailed arithmetic and scheduling remain in deterministic unit/integration tests rather than
duplicated UI journeys.

## Documentation

When implementation is complete, update:

- `docs/rfc/orders.md`;
- relevant reminder, pricing, inventory, and persistence RFC cross-links;
- `README.md`;
- `wiki/Business-Concepts.md`;
- `wiki/Owner-Workflows.md`;
- `wiki/Current-App-Capabilities.md`;
- `wiki/Inventory-Guide.md` when reservation availability changes owner-visible inventory meaning.
