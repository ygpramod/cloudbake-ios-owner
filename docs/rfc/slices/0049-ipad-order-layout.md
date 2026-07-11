# Slice RFC-0049: Deferred iPad Order Layout

## Status

Deferred by the iPhone-only owner app direction.

## Parent RFC

- `docs/rfc/orders.md`

## Authority And Scope

This slice previously adapted the owner Orders workflow for regular-width iPad layouts. iPad is no
longer supported for the initial owner app, so this behavior has been removed from the active app and
may be reconsidered through a future RFC.

This slice includes:

- keeping the modal order detail flow on supported iPhones.

This slice does not include:

- tablet-specific analytics,
- multi-order drag and drop,
- bulk status changes,
- calendar drag scheduling,
- pricing or design layout changes.

## Requirements

- The iPhone order workflow must remain unchanged.
- Add order, edit order, status change, reminders, recipe usage, customer context, and checklist
  workflows must remain reachable from Orders.

## Design

`OrderListView` uses the list and sheet-based detail flow on supported iPhones.

## Testing

- The former iPad split-view acceptance test is removed while iPad is unsupported.
- A targeted iPhone acceptance test verifies that the list-to-detail workflow still opens
  order detail.
- Existing order view-model and persistence tests continue to cover order loading, detail state,
  reminders, recipe usage, and checklist behavior.

## Documentation Updates

- `README.md` lists Slice RFC-0049 as deferred.
- `docs/rfc/orders.md` records iPad order layout as deferred.
- `wiki/Current-App-Capabilities.md` lists iPad order layout as deferred.
- `wiki/Owner-Workflows.md` describes iPad order workflow as deferred.
