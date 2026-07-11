# Slice RFC-0043: Deferred iPad Customer Layout

## Status

Deferred by the iPhone-only owner app direction.

## Parent RFC

- `docs/rfc/customers.md`

## Authority And Scope

This slice previously adapted the customer workflow for regular-width iPad layouts. iPad is no
longer supported for the initial owner app, so this behavior has been removed from the active app and
may be reconsidered through a future RFC.

This slice includes:

- keeping the modal customer detail flow on supported iPhones.

This slice does not include:

- multi-column customer analytics,
- drag and drop,
- bulk customer actions,
- customer-facing account screens,
- order editing from customer detail.

## Requirements

- The iPhone customer workflow must remain unchanged.
- Add, edit, contact import, duplicate warning, preferences, important dates, and order history must
  remain reachable from the customer workflow.

## Design

`CustomerListView` uses the list and sheet-based detail flow on supported iPhones.

## Testing

- Existing customer view-model tests continue to cover customer loading, detail selection, editing,
  duplicate detection, important dates, and linked order history.
- The former iPad split-view acceptance test is removed while iPad is unsupported.

## Documentation Updates

- `README.md` lists Slice RFC-0043 as deferred.
- `docs/rfc/customers.md` records iPad customer layout as deferred.
- `wiki/Current-App-Capabilities.md` lists iPad customer layout as deferred.
- `wiki/Owner-Workflows.md` describes iPad customer workflow as deferred.
