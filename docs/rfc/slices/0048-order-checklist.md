# Slice RFC-0048: Order Checklist

## Authority And Scope

This slice adds simple owner checklist items to order detail. It supports preparation tasks that
belong to a specific cake order without trying to become a full task manager.

In scope:

- storing checklist items for one order,
- showing checklist items in order detail,
- adding a checklist item from order detail,
- marking a checklist item complete or incomplete from order detail,
- keeping incomplete items before completed items.

Out of scope:

- checklist item editing,
- checklist item deletion,
- checklist reordering,
- templates,
- reminders based on checklist items,
- automatic status changes from checklist completion.

## Requirements Summary

- Order detail must show a Checklist section.
- Empty checklists must show a calm empty state.
- The owner must be able to add a checklist item with a non-empty title.
- The owner must be able to tap a checklist row to toggle completion.
- Completed items must remain visible.
- Checklist items must persist locally with their order.
- Checklist items must be deleted automatically if their order is deleted.

## Non-Functional Requirements

- The implementation must reuse existing local-first GRDB repository patterns.
- Tests must cover view-model behavior, persistence ordering, and the owner acceptance path.
- The UI must stay compact because order detail already contains status, customer, recipe,
  reminder, and future pricing/design sections.

## Design

`OrderChecklistItem` is a child record of `Order`. Migration
`0010_create_order_checklist_items` creates `order_checklist_items` with a cascading foreign key to
`orders`.

Checklist fetches order incomplete items first, then by sort order and creation time. This keeps the
owner's remaining preparation work visible while retaining completed history for the order.

`OrderListViewModel` owns selected-order checklist state. It loads checklist items when order
detail opens, clears them when detail closes, saves new trimmed titles, and toggles item completion
through the repository.

`OrderDetailView` shows checklist rows as tappable rows with completion icons and a compact add row.
The add field dismisses focus after a successful save so the next tap can immediately interact with
the checklist.

## Testing

- Unit tests cover loading checklist items when viewing an order, adding a trimmed checklist item,
  and toggling completion.
- Integration tests cover GRDB checklist save/fetch and ordering incomplete items before completed
  items for one order.
- Acceptance test covers adding an order, adding a checklist item from detail, and marking it
  complete.

## Documentation Updates

- `README.md` lists Slice RFC-0048.
- `docs/rfc/orders.md` records the implemented checklist slice.
- `wiki/Current-App-Capabilities.md` lists owner order checklist support.
- `wiki/Owner-Workflows.md` explains the checklist workflow in order detail.
- `wiki/Business-Concepts.md` defines an order checklist item.
