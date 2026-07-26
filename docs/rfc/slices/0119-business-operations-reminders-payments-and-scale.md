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

Implementation status: complete in this improvement point. The owner app now persists reservation
rows and audit events, repairs eligible migrated orders in bounded background batches, reads
reservation planning state in chunked aggregate queries, and shows each current reservation
concisely in order detail.

### Business Rules

1. Draft and Cancelled orders have no active reservation. Draft demand remains a forecast under
   RFC-0098; it is not committed stock.
2. Confirmed and In Progress orders with no recorded recipe usage reserve their complete scaled
   recipe and extra-ingredient requirements.
3. Moving an order into Confirmed creates or replaces its reservation atomically with the status
   change.
4. Editing an order's recipe link, multiplier, or extra ingredients, or editing ingredients in a
   recipe used by an unconsumed reserved order, atomically replaces every affected reservation.
   If any affected requirement is invalid or cannot be converted, the entire edit fails with a
   specific owner-facing message; neither recipe data nor reservations are partially saved.
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
11. Moving an order that already has recorded usage from Ready or Completed back to Confirmed or In
    Progress never creates another reservation or reverses consumption. The UI identifies that
    inventory was already deducted. Subsequent ingredient edits do not alter consumed inventory;
    any additional consumption is a separate future workflow and is out of scope here.
12. Current reservation rows are replaced or deleted, while every create, quantity replacement,
    release, consumption release, and repair failure appends an immutable reservation event. The
    event records old and new quantities, the reason, and occurrence time so reservation changes are
    auditable without pretending they changed physical stock.
13. Existing eligible Confirmed and In Progress orders are repaired deterministically from their
    saved recipes, multipliers, and extras after migration. Orders whose requirements cannot be
    converted remain usable and surface a persisted repair warning instead of silently reserving
    zero.

### Availability And Projection Equations

For an inventory item:

- `usable` is the total non-expired available stock;
- `reservedAll` is the total of current Confirmed/In Progress reservations without recorded usage;
- `reservedOther(order)` is `reservedAll` minus that order's existing reservation;
- `proposed(order)` is the order's newly calculated complete requirement;
- `affectedOld(set)` is the total current reservation for every order affected by one recipe edit;
- `affectedProposed(set)` is the total newly calculated requirement for that same set;
- `forecastOnly` is the live requirement of Draft orders and unconsumed Ready orders.

The owner-facing calculations are:

1. General available-to-promise: `usable - reservedAll`.
2. Initial confirmation or reservation replacement shortfall:
   `max(proposed(order) - max(usable - reservedOther(order), 0), 0)`.
3. Multi-order recipe replacement shortfall:
   `max(affectedProposed(set) - max(usable - (reservedAll - affectedOld(set)), 0), 0)`.
4. Aggregate projected shortage:
   `max(reservedAll + forecastOnly - usable, 0)`.

Confirmed/In Progress demand is read from its reservation and never also recalculated as forecast
demand. A Pending or Failed repair contributes its live requirement exactly once until its
reservation is repaired, even if stale reservation rows are present. A Complete repair may
intentionally contain no rows. A corrupt Complete reservation falls back to the live requirement
instead of silently understating demand. A recipe edit validates all affected proposed requirements
as one set before writing any recipe or reservation row; it does not validate each order
independently. These equations preserve RFC-0098's Draft warning while preventing a reservation
from being subtracted or counted twice.

### Persistence

Add one `order_inventory_reservations` row per order and inventory item:

- stable id;
- order id;
- inventory item id;
- required quantity in the inventory item's unit;
- unit;
- created and updated timestamps;
- a unique key on order id plus inventory item id.

Add append-only `order_inventory_reservation_events` rows containing:

- stable event id;
- order id and, when the failed requirement can be identified, inventory item id;
- event kind and reason;
- previous and new quantities in the inventory item's unit;
- occurrence timestamp.

Normal reservation events require an inventory item and unit. A repair-failure event may leave the
item or unit empty when the broken legacy requirement cannot be represented safely; the persisted
typed repair code remains the owner-facing recovery signal.

Add one `order_inventory_reservation_repairs` row per eligible pre-migration order. Its state is
Pending, Complete, or Failed, with attempt count, last attempted time, and a typed failure code.
Migration inserts Pending rows only for Confirmed/In Progress orders without recorded usage. An
activation repair processes a fixed batch, replaces reservations idempotently, appends events, and
marks each row Complete in the same transaction. Interrupted work stays Pending; Failed work is
retryable and owner-visible. Restored Pending or Failed rows follow the same safe repair path.

Index inventory item id for aggregate availability queries. Reservation replacement, audit event,
repair status, order status, order usage, ingredient costs, inventory transactions, and stock-batch
updates must share the existing database transaction boundary where they occur together.

## Reminder Customization

Implementation status: complete in this improvement point. Reminder defaults and per-order plans
are persisted, validated, included in database backup/restore, and used by both in-app presentation
and local notification scheduling. Saving an order reminder change replaces pending order reminder
requests immediately.

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

The owner confirmed that customization includes both global defaults and per-order overrides.

## Daily Payment-Pending Reminder

Implementation status: scheduling foundation complete; final Outstanding-report routing,
shared-budget allocation, and the end-to-end acceptance journey remain part of this improvement
point. CloudBake records the first known completion time for newly completed orders, uses one
shared eligibility rule for the Reminders screen and local notification, persists the
owner-selected daily time, and refreshes aggregate requests after order, status, payment, settings,
launch, foreground, and restore changes.

### Business Rules

1. An order becomes eligible only when:
   - status is Completed;
   - its due date/time has passed; and
   - its derived balance due is greater than zero.
2. Readiness alone does not start payment-pending reminders.
3. The reminder fires once per calendar day at the owner-selected reminder time. The initial
   recommendation is 9:00 AM.
4. If the order becomes eligible after today's reminder time, the first reminder is tomorrow.
5. CloudBake uses at most one aggregate payment-pending notification per calendar day while any
   order is eligible. The local-only scheduler plans a rolling 14-day set of date-keyed one-shot
   requests and refreshes that horizon on launch and foreground because iOS cannot defer the start
   of an indefinite daily repeating local notification. The later shared allocator keeps these
   requests within the 60-slot app budget. Each notification shows the outstanding-order count and
   deep-links to the Outstanding payment report.
6. Marking the order Paid removes its pending payment reminder immediately.
7. Reducing the balance without paying it in full keeps the reminder active with the updated
   balance.
8. Reopening or cancelling the order removes the payment reminder.
9. Notification authorization denial must not block payment recording or order completion.
10. The in-app Reminders payment section uses the same eligibility rule as notification scheduling.

Persist `completedAt` when an order first enters Completed. Leaving and later re-entering Completed
does not overwrite it. Existing completed orders keep `completedAt` null and display the completion
time as Legacy/Unknown because their mutable `updatedAt` is not trustworthy completion history.
Payment eligibility still uses status and due time, so the nullable legacy value never suppresses a
valid reminder. Later payment changes must not alter `completedAt`.

The owner confirmed that the payment reminder time is globally customizable. It is part of Reminder
Settings and defaults to 9:00 AM.

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
9. After migration, the paid total is derived from receipt operations and is read-only in Edit
   Order. Add Order may accept an initial payment only by saving the order and its opening receipt
   atomically. Existing Add/Edit aggregate mutations and direct repository saves may not change the
   paid total. This rule supersedes RFC-0053's directly editable paid/deposit total.
10. Migration copies an existing paid aggregate into a separate immutable `legacyPaidAmount`.
    Derived paid total is `legacyPaidAmount + non-void receipt amounts`, so new receipt operations
    reconcile without fabricating historical events. After the owner approves the legacy rule
    below, an atomic migration may convert that amount to a labelled opening receipt and zero the
    legacy field, or keep it outside the receipt ledger.

### Owner Interview Decisions

The first reporting release contains exactly three reports:

1. Payment Ledger;
2. Order Profitability;
3. Sales & Orders.

The Payment Ledger is a full ledger containing both money received and money still outstanding,
with summary totals and order drill-down. It opens on the Outstanding filter because that is the
actionable owner view.

Payment Ledger and Sales & Orders let the owner switch between Day, Week, and Month grouping and
default to a rolling 12-month period ending today, grouped by Month. The owner can switch the
grouping or choose a custom date range. Order Profitability remains an order-by-order list with
date filters rather than grouped totals and uses the same rolling 12-month default.

Inventory usage and waste, upcoming workload, customer summary, and recipe/design popularity
reports are outside this improvement point.

The following also require owner confirmation before implementation:

1. whether a date filter applies to payment received date, order due date, or both through separate
   filters;
2. whether payment method is required;
3. whether correcting a mistaken receipt means a reversible void/correction entry or editable
   history;
4. whether pre-migration aggregate paid amounts should become one clearly labelled opening receipt
   or remain outside the receipt ledger with a migration note;
5. whether CSV export is required in this slice.

Do not implement the report UI or destructive payment correction behavior until these decisions are
recorded here.

## Scale-Oriented Order Queries

### Query Contract

Replace feature-level `fetchOrders()` plus in-memory filtering with repository queries shaped for
their consumers:

All list queries use keyset pagination ordered by their business sort plus order or receipt id as a
stable tiebreaker. The default page size is 25 and callers cannot request more than 50 rows. SQL
aggregate queries may return counts and totals without loading their contributing rows.

1. Active Orders:
   - statuses limited to Draft, Confirmed, In Progress, and Ready;
   - due-date ordering in SQL;
   - required page limit and cursor; an optional due-date range may narrow the page but cannot remove
     the page bound.
2. Completed history:
   - Completed and Cancelled only;
   - reverse due-date ordering;
   - keyset paging with the fixed page size and stable tiebreaker.
3. Home upcoming orders:
   - active orders from the start of today through the existing 30-day window;
   - paged with the same hard limit.
4. Reminder scheduling:
   - candidates ordered by their next trigger time;
   - due no later than the largest configured lead-time window;
   - hard-limited to the remaining shared notification capacity.
5. Payment reminders/report:
   - one SQL count/total for aggregate notification content;
   - Outstanding rows are paged;
   - receipt-history queries require a date range no longer than 366 days and are paged.
6. Customer history:
   - only orders for the selected customer, ordered and paged with the hard limit.
7. Design/reference workflows:
   - exact relationship-id lookup where one result is expected;
   - otherwise ordered and paged with the hard limit.
8. Reservation planning:
   - availability and shortage screens use SQL aggregates by inventory item;
   - repair reads Pending/Failed orders in batches of at most 50.

Keep `fetchOrder(id:)` for direct navigation. Retain `fetchOrders()` only as a test/support or
explicit export boundary; production screens must move to bounded queries in this slice.

### Shared Notification Budget

CloudBake owns one notification-budget allocator with a maximum of 60 app-scheduled pending
requests, retaining four system slots below iOS's documented 64-request limit. Every producer,
including operational orders, inventory-expiry batches, the payment summary, and backup reminders,
must submit candidates to this allocator rather than scheduling independently. The single payment
summary request and backup reminder are allocated first. Remaining order and inventory-expiry
candidates are merged by nearest trigger time, then business due/expiry time, category, and stable
id. Each producer queries no more candidates than the remaining capacity. The scheduler reconciles
on launch, foreground, reminder-setting changes, order changes, inventory/batch changes, payment
changes, restore activation, and significant date changes. In-app Reminders remains complete even
when a later local notification is outside the current scheduling window.

### Indexes And Performance

Add or verify indexes for:

- order status plus due date;
- customer id plus due date;
- completed-at plus payment eligibility;
- reservation inventory item id;
- payment received-at;
- payment order id plus received-at.

Persistence tests must verify query ordering, hard bounds, paging stability, aggregate correctness,
and query-plan index use for the high-volume paths. A deterministic scale fixture must seed at least
1,000 orders and 2,000 payment receipts and prove the main list and report paths return no more than
their requested page, use the intended indexes, and execute a bounded number of SQL statements.
Wall-clock measurements may be recorded as non-gating diagnostics; they are not CI assertions.

## Migration And Backup Safety

1. All new state uses explicit forward-only GRDB migrations.
2. Fresh-database migration coverage must include every new table, column, constraint, and index.
3. Existing orders remain readable before reservation repair completes, and their persisted repair
   state survives backup, restore, interruption, and retry.
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

1. Reservation eligibility, replacement excluding the order's current claim, release, post-usage
   reopening, projected-demand equations, full-demand shortage, and unit conversion.
2. Reminder configuration validation and effective-plan selection.
3. Payment-reminder eligibility and next 9:00 AM scheduling with injected clock/calendar.
4. Payment receipt arithmetic, remaining-balance receipt, and correction rules after owner approval.
5. Query input validation and pagination cursor behavior.

### Integration

1. Migration from the current schema and fresh database.
2. Atomic reservation creation/replacement/release, audit events, idempotent repair, and consumption.
3. Atomic payment receipt plus paid-total update.
4. Bounded, ordered, indexed order and payment queries plus notification-budget prioritization.
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
