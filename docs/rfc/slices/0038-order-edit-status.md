# Slice RFC-0038: Order Edit And Status Changes

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice lets the owner correct active order details and move an order through its operational
status lifecycle.

This slice includes:

- edit action from order detail,
- editable cake name,
- editable customer snapshot name,
- editable customer record link,
- editable due date and time,
- editable pickup or delivery fulfillment type,
- editable delivery address,
- editable cake notes,
- manual order status changes across the existing lifecycle,
- focused view-model and acceptance coverage.

This slice does not include:

- order calendar view,
- customer preference or allergy surfacing inside orders,
- order reminders,
- pricing and payment,
- design references and photos,
- recipe links,
- inventory deduction,
- checklist automation.

## Requirements

- The owner can open an order detail screen and choose edit.
- The edit form is prefilled from the selected order.
- The owner can change order details and save them.
- The owner can manually change order status after creation.
- Saving an edit preserves the original order identity and creation timestamp.
- Saving an edit updates the order list and currently viewed order detail.
- Validation remains consistent with add order: cake name and customer name are required.

## Design

The existing add-order form is reused as a configurable order form. Add order still exposes only
Draft and Confirmed statuses, while edit order exposes the full `OrderStatus` lifecycle:

- Draft,
- Confirmed,
- In Progress,
- Ready,
- Completed,
- Cancelled.

`OrderListViewModel` keeps `selectedOrder` for detail display and `editingOrder` for save context.
Edited orders are persisted through the existing `OrderRepository.save(_:)` path, which already
updates by order ID.

## Testing

- View-model tests cover edit prefill, validation reuse, persistence of edited fields, preservation
  of order identity, and status transition save.
- Acceptance coverage confirms an order can be edited from detail and the updated detail is shown
  after save.

## Documentation Updates

- `README.md` lists Slice RFC-0038.
- `docs/rfc/orders.md` records the edit/status slice as implemented.
- `wiki/Current-App-Capabilities.md` lists order editing and status changes.
- `wiki/Owner-Workflows.md` describes the updated order workflow.
