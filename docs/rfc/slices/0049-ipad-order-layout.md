# Slice RFC-0049: iPad Order Layout

## Status

Implemented

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice adapts the owner Orders workflow for regular-width iPad layouts while preserving the
existing iPhone order flow.

This slice includes:

- using an order list/detail split view on regular-width layouts,
- showing an empty order-detail state until an order is selected,
- opening selected order detail inline on iPad,
- keeping the existing modal detail flow on compact iPhone layouts,
- keeping List and Calendar display modes available on iPad,
- focused acceptance coverage for iPad split-view behavior and iPhone compact behavior.

This slice does not include:

- iPad-specific analytics,
- multi-order drag and drop,
- bulk status changes,
- calendar drag scheduling,
- pricing or design layout changes.

## Requirements

- iPad order navigation must make better use of the wider screen.
- The owner must be able to keep the order list or calendar visible while reviewing order detail on
  iPad.
- The iPhone order workflow must remain unchanged.
- Add order, edit order, status change, reminders, recipe usage, customer context, and checklist
  workflows must remain reachable from Orders.

## Design

`OrderListView` now adapts on horizontal size class:

- compact layouts keep the list and sheet-based detail flow,
- regular layouts use `NavigationSplitView` with the order list/calendar/reminders in the sidebar
  and selected order detail in the detail column.

The detail view hides the Done action when embedded inline, because there is no modal to dismiss on
iPad.

## Testing

- A targeted iPad acceptance test verifies that regular-width layout shows the empty detail state,
  opens selected order detail inline, and does not show the modal Done action.
- A targeted iPhone acceptance test verifies that the compact list-to-detail workflow still opens
  order detail.
- Existing order view-model and persistence tests continue to cover order loading, detail state,
  reminders, recipe usage, and checklist behavior.

## Documentation Updates

- `README.md` lists Slice RFC-0049.
- `docs/rfc/orders.md` records iPad order layout as implemented.
- `wiki/Current-App-Capabilities.md` lists regular-width iPad order split view.
- `wiki/Owner-Workflows.md` describes the iPad order workflow behavior.
