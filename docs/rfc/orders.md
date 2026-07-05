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
- The owner must be able to see upcoming orders in a list and calendar-oriented view.
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

## Reminder Model

Default order reminders:

- three days before due date,
- two days before due date,
- one day before due date.

Future reminder behavior can include day-of reminders, snooze, preparation-start reminders, and
calendar integration. Reminder slices must define whether reminders are local notifications,
in-app alerts, or both.

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

The first order model should capture quoted price, deposit paid, balance due, and payment notes
without trying to automate the full pricing calculation.

## Recipe And Inventory Relationship

Orders should eventually link to one or more recipes. When the owner marks a recipe as used for an
order, inventory should be deducted from the oldest-expiring stock batches first.

This relationship should be implemented after order foundations and recipe ingredient rows are
stable enough to support reliable stock deduction.

## Design And Photo Relationship

Orders should eventually link to:

- previous cake photos,
- customer reference images,
- final cake photos,
- design notes,
- minor improvement requests.

The initial order RFC does not require AI design suggestions. The design memory should be built
with owner-reviewed photos and notes first.

## Implementation Slices

Recommended order slices:

1. Orders List, Add Order, And Detail
2. Order Edit And Status Changes
3. Orders Calendar View
4. Customer Preferences And Allergy Details
5. Pricing And Payment Summary
6. Order Reminders
7. Order Design References And Photos
8. Recipe Link From Order
9. Order Recipe Usage And Inventory Deduction
10. Order Checklist
11. iPad Order Layout
12. Future Consumer Order Preview Model

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

## Open Questions

- Should due date mean cake ready time, delivery time, or both?
- Should delivery address be required only for delivery orders?
- Should a draft order support customer name only, or should contact details be required before confirmation?
- Should payment currency be an app setting or hard-coded initially for the owner?
- Should customer preferences be copied into the order as a snapshot or linked to a separate customer record?
- Should reminders be based on due date, preparation start date, or both?
- Should allergy warnings block order confirmation or only alert the owner?
