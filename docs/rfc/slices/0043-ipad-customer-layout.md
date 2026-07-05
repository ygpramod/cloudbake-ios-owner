# Slice RFC-0043: iPad Customer Layout

## Status

Implemented

## Parent RFC

- `docs/rfc/customers.md`

## Authority And Scope

This slice adapts the customer workflow for regular-width iPad layouts while preserving the existing
iPhone customer flow.

This slice includes:

- using a customer list/detail split view on regular-width layouts,
- showing an empty customer-detail state until a customer is selected,
- opening selected customer detail inline on iPad,
- keeping the existing modal detail flow on compact iPhone layouts,
- focused acceptance coverage for the iPad split-view behavior.

This slice does not include:

- multi-column customer analytics,
- drag and drop,
- bulk customer actions,
- customer-facing account screens,
- order editing from customer detail.

## Requirements

- iPad customer navigation must make good use of the wider screen.
- The owner must be able to keep the customer list visible while reviewing customer detail on iPad.
- The iPhone customer workflow must remain unchanged.
- Add, edit, contact import, duplicate warning, preferences, important dates, and order history must
  remain reachable from the customer workflow.

## Design

`CustomerListView` now adapts on horizontal size class:

- compact layouts keep the list and sheet-based detail flow,
- regular layouts use `NavigationSplitView` with the customer list in the sidebar and selected
  customer detail in the detail column.

The detail view hides the Done action when it is embedded inline, because there is no modal to
dismiss on iPad.

## Testing

- Existing customer view-model tests continue to cover customer loading, detail selection, editing,
  duplicate detection, important dates, and linked order history.
- A targeted acceptance test verifies that regular-width iPad layout shows the empty detail state,
  opens selected customer detail inline, and does not show the modal Done action.
- The iPad acceptance test skips on compact devices so the iPhone CI lane remains focused.

## Documentation Updates

- `README.md` lists Slice RFC-0043.
- `docs/rfc/customers.md` records iPad customer layout as implemented.
- `wiki/Current-App-Capabilities.md` lists regular-width iPad customer split view.
- `wiki/Owner-Workflows.md` describes the iPad customer workflow behavior.
