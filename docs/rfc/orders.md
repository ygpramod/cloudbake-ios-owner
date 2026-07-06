# Orders RFC

## Status

Draft

## Authority And Scope

This RFC is the product and engineering authority for owner-side order management in the
CloudBake iOS owner app. Slice RFCs for order implementation must reference this document and
capture any deliberate changes to this model.

This RFC applies to:

- owner-created orders,
- order calendar and list views,
- order detail and status tracking,
- customer details needed for an order,
- cake requirements,
- fulfillment details,
- pricing and payment summary,
- order reminders,
- future links to recipes, inventory, designs, and cake photos.

This RFC does not cover:

- public customer ordering,
- online payment processing,
- tax or accounting reports,
- delivery route optimization,
- multi-user staff workflows,
- backend sync,
- AI-assisted cake design suggestions.

Those areas can be added later through separate RFCs when the owner workflow needs them.

## Product Goals

Orders should help the owner answer:

1. what cakes are due,
2. who the cake is for,
3. what needs to be made,
4. when it must be ready,
5. whether it is pickup or delivery,
6. what the customer requested,
7. what the owner quoted and collected,
8. what preparation reminders are coming up.

The app should stay owner-first and practical for handmade cakes. It should support judgement,
notes, and changing customer requests without forcing the owner into a rigid retail checkout flow.

## Requirements Summary

- The owner must be able to create an order from the app.
- The owner must be able to see upcoming active orders in a calendar-oriented view.
- The Orders screen must expose only Active and Completed tabs.
- Active orders must be grouped by due day and ordered by delivery/pickup date-time ascending.
- Completed and cancelled orders must move out of the active Orders view into a Completed tab.
- Completed tab orders must display as a simple ungrouped list ordered by delivery/pickup date-time
  descending, with cancelled orders visibly marked.
- The owner must be able to view a single order with all business-critical details.
- The owner must be able to edit an order while it is active.
- Each order must have a status.
- Each order must capture a due date and time.
- Each order must capture whether it is for pickup or delivery.
- Each order must capture customer name and contact information.
- Each order must capture customer likes, dislikes, allergies, and special notes when known.
- Each order must capture cake type, flavor, size, servings, message text, and design notes when known.
- Each order must support owner-controlled price and payment tracking.
- Each order must support reminders three days, two days, and one day before due date.
- Orders screen must not show a separate Reminders Due section; reminder context should stay in the
  main order presentation and order detail.
- Order checklist items must stay ordered by entry order and support deletion.
- Each order must be able to link to cake photos, design references, recipes, and inventory usage in later slices.
- The app must preserve order history after completion.

## Non Functional Requirements

- The first implementation must be local-first and usable without network access.
- Order data must use app storage patterns already established for inventory and recipes.
- Order persistence must be migration-friendly.
- Tests are required for business rules and critical owner workflows.
- Acceptance tests should cover only impacted workflows during local development; CI remains the broader safety net.
- The UI must work well on iPhone and remain extendable for iPad.
- Allergy and customer preference details must be visible where they can affect cake preparation.
- Private owner information must not be designed in a way that leaks into future customer-facing surfaces.
- Future backend communication must carry correlation IDs for end-to-end traceability.
- Order screens should remain calm and scannable; important details should not be hidden behind decorative layout.

## Domain Model

The order model should start small and grow deliberately.

Core concepts:

- `Order`: the aggregate root for an owner order.
- `OrderStatus`: the current operational state.
- `OrderCustomerSnapshot`: customer details relevant at the time of the order.
- `OrderCakeDetails`: cake-specific requirements.
- `OrderFulfillment`: pickup or delivery details.
- `OrderPricing`: quoted price, deposit, balance, and owner notes.
- `OrderReminderPlan`: reminder offsets and scheduled reminder state.
- `OrderChecklistItem`: future preparation tasks for an order.

The initial local model should prefer explicit columns for core fields and child tables only where
the data is naturally repeatable, such as checklist items, photos, or future order events.

## Status Lifecycle

Initial order statuses:

1. Draft
2. Confirmed
3. In Progress
4. Ready
5. Completed
6. Cancelled

Draft orders are not yet committed work. Confirmed orders are accepted by the owner. In Progress
orders are being prepared. Ready orders are finished and waiting for pickup or delivery. Completed
orders are fulfilled. Cancelled orders remain in history but should not appear as active work.

The owner should be able to change status manually. Later slices may suggest status changes based
on checklist completion, delivery date, recipe usage, or payment state.

## Owner Experience

Orders should eventually include these screens:

- Orders list grouped by due date.
- Calendar view for due dates.
- Completed orders tab.
- Add order flow.
- Order detail view.
- Edit order flow.
- Status change actions.
- Pricing and payment section.
- Reminder section.
- Design and photo section.
- Recipe and inventory section.

The first slice should avoid building every section. It should establish the order model, list,
add, and detail foundations.

The first order slice is implemented in `docs/rfc/slices/0037-orders-list-add-detail.md`. Order
editing and manual status changes are implemented in `docs/rfc/slices/0038-order-edit-status.md`.
The calendar-oriented order view is implemented in `docs/rfc/slices/0039-orders-calendar-view.md`.
Linked customer preference and allergy details in order detail are implemented in
`docs/rfc/slices/0040-order-customer-preferences.md`.
Customer detail can show linked order history through
`docs/rfc/slices/0041-customer-order-history.md`.
Order add/edit can link customers through a searchable selection flow through
`docs/rfc/slices/0042-order-customer-search-selection.md`.
Owner-visible order reminder planning is implemented in
`docs/rfc/slices/0044-order-reminders.md`.
Order add/edit can link one saved recipe for preparation context through
`docs/rfc/slices/0046-order-recipe-link.md`.
Order detail can change status without opening the full edit form. Moving a Confirmed order with an
unused linked recipe to Ready or Completed records one-time recipe usage and deducts recipe
ingredients from inventory through
`docs/rfc/slices/0047-order-recipe-usage-inventory-deduction.md`.
Order detail can now store simple preparation checklist items through
`docs/rfc/slices/0048-order-checklist.md`.
Regular-width iPad layouts now show Orders as a list/detail split view through
`docs/rfc/slices/0049-ipad-order-layout.md`.
A customer-safe order preview model for future consumer-facing surfaces is implemented through
`docs/rfc/slices/0050-future-consumer-order-preview-model.md`.
Order add/edit can link one existing cake design reference, and order detail can show the linked
design name, notes, and photo reference through
`docs/rfc/slices/0051-order-design-reference.md`.
Completed order tab behavior, calendar default view, removal of the standalone Reminders Due
section, and checklist deletion/order behavior are implemented through
`docs/rfc/slices/0052-order-workflow-polish.md`.
Order add/edit can capture owner-entered quoted price, deposit paid, and payment notes; order detail
shows the derived balance and payment status through
`docs/rfc/slices/0053-order-pricing-payment-summary.md`.
The Orders screen now exposes only Active and Completed tabs. Active orders are grouped by due day
and ordered by delivery/pickup time ascending; completed and cancelled orders are shown in a simple
list ordered by delivery/pickup date-time descending, with cancelled rows visibly marked, through
`docs/rfc/slices/0054-order-active-completed-tabs.md`.
Order rows now expose quick status and payment swipe actions, and order detail can record Paid or
Part Paid changes without opening full edit, through
`docs/rfc/slices/0055-order-status-payment-quick-actions.md`.
Confirmed, In Progress, and Ready orders now schedule local iOS notifications for future three-day,
two-day, and one-day reminder offsets through
`docs/rfc/slices/0056-order-scheduled-reminder-notifications.md`.

## Reminder Model

Default order reminders:

- three days before due date,
- two days before due date,
- one day before due date.

Future reminder behavior can include day-of reminders, snooze, preparation-start reminders, and
calendar integration. Reminder slices must define whether reminders are local notifications,
in-app alerts, or both.

The first reminder slice provides in-app reminder planning. Order detail shows the next reminder
from the three/two/one-day reminder plan. The Orders screen should avoid a standalone Reminders Due
section because reminder context belongs in the main order presentation and order detail.

Confirmed, In Progress, and Ready orders now schedule local iOS notifications for future
three/two/one-day reminder offsets. Draft, Completed, Cancelled, past-due, and already-missed
reminders do not schedule notifications. Snooze, configurable offsets, day-of reminders, and
calendar integration remain future work.

## Pricing And Payment

CloudBake can suggest pricing later, but the final price must remain owner controlled.

Pricing inputs may eventually include:

- ingredients,
- size,
- servings,
- design complexity,
- owner time,
- packaging,
- delivery,
- deposit,
- discounts,
- manual override.

The first order model captures quoted price, deposit paid, derived balance due, payment status, and
payment notes without trying to automate the full pricing calculation.

Quick payment actions keep the same owner-controlled model. Marking Paid sets paid amount equal to
the quoted price, which makes derived balance due zero. Adding a partial payment asks for the newly
received amount, adds it to the existing paid amount, and rejects invalid or excess payment values.

## Recipe And Inventory Relationship

Orders can now link to one saved recipe. When the owner marks a Confirmed order with an unused
linked recipe as Ready or Completed from order detail or through edit order, inventory is deducted
from the recipe ingredient rows. Ingredient quantities are converted into the linked inventory
item's stored unit when compatible, and stock batches are consumed from the oldest expiry first with
no-expiry batches last.

Recipe usage is owner-confirmed and one-time per order. Recipe scaling, partial recipe usage,
multi-recipe orders, and inventory reservation remain future work.

## Design And Photo Relationship

Orders should eventually link to:

- previous cake photos,
- customer reference images,
- final cake photos,
- design notes,
- minor improvement requests.

The initial order RFC does not require AI design suggestions. The design memory should be built
with owner-reviewed photos and notes first.

Orders can now link to one existing cake design. This is a reference to saved design memory. Order
detail can also store order-specific customer reference photos and final cake photos locally, from
the photo library or camera capture. Saved order photos can be opened in a full-screen preview, and
their captions can be edited from that preview. Multiple design references, promoting final cake
photos into the saved design library, and broader design library management remain future work.

## Implementation Slices

Recommended order slices:

1. Orders List, Add Order, And Detail
2. Order Edit And Status Changes
3. Orders Calendar View
4. Customer Preferences And Allergy Details
5. Order Reminders
6. Recipe Link From Order
7. Order Recipe Usage And Inventory Deduction
8. Order Checklist
9. iPad Order Layout
10. Future Consumer Order Preview Model
11. Order Design References And Photos
12. Order Workflow Polish
13. Pricing And Payment Summary

Each slice must include its own RFC under `docs/rfc/slices/`, focused tests, and wiki updates when
owner workflow truth changes.

## First Slice Recommendation

The first implementation slice should create the minimum useful order foundation:

- list orders,
- add an order,
- view order detail,
- persist order data locally,
- capture title or cake name,
- capture customer name,
- capture due date and time,
- capture pickup or delivery,
- capture cake notes,
- capture status,
- include focused unit, integration, and acceptance coverage.

This keeps the slice small enough to review while creating a real base for calendar, reminders,
pricing, and recipe links.

## Decisions

- Due date means delivery time.
- Delivery address is not mandatory.
- A draft order only requires customer name.
- Payment currency should come from an app setting.
- Customer preferences should link to a separate customer record.
- The Customer RFC should be implemented before customer preference details are added to orders.
- Order reminders should be based on due date.
- Allergy warnings should alert the owner only and should not block order confirmation.
- The first implemented order foundation supports list, add, detail, customer name snapshots,
  optional customer record links, due date/time, draft or confirmed status, pickup or delivery,
  optional delivery address, and cake notes.
- Order detail now surfaces non-empty allergies, dietary restrictions, likes, dislikes, and notes
  from the linked customer record for owner visibility.
- Orders now plan in-app reminders three days, two days, and one day before due date. The UI shows
  only the next relevant reminder, and completed or cancelled orders are excluded from due reminder
  alerts.
- Orders can now change status from detail without opening the full edit form.
- Orders can now deduct linked recipe ingredients once when a Confirmed order is marked Ready or
  Completed.
- Orders can now store owner checklist items in order detail. Checklist items remain in entry order
  and support add, complete/incomplete toggle, and deletion; edit, reorder, templates, and
  checklist-driven status changes remain future work.
- Orders now use a regular-width iPad split view so the list and calendar can remain
  visible while reviewing selected order detail. Compact iPhone layouts keep the modal detail flow.
- Orders now expose only Active and Completed tabs. Active work is always shown as due-day groups
  ordered by delivery/pickup time ascending. Completed and cancelled work is an ungrouped history
  list ordered by delivery/pickup date-time descending, with cancelled rows visibly marked. The
  standalone Orders screen Reminders Due section is removed; order detail continues to show the next
  relevant reminder.
- Orders now expose row swipe actions for quick status changes and payment recording. Order detail
  can also mark an order Paid or add a partial payment without opening full edit.
- Orders now schedule local owner notifications for future three-day, two-day, and one-day
  reminders when the order is Confirmed, In Progress, or Ready.
- Orders now have a customer-safe preview projection for future consumer surfaces. It maps owner
  statuses into consumer language and deliberately excludes private owner/customer operational
  fields.

## Open Questions

- Should pickup orders also use due date as the pickup time?
