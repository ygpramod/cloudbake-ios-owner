# Slice RFC-0033: Inventory Detail Actions

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Make common stock actions easy to reach from the inventory item detail screen without cluttering
the top toolbar.

## Scope

- Replace the text Edit action in inventory detail with a pencil icon action.
- Add an inventory detail more menu for:
  - history,
  - use stock,
  - adjust stock.
- Keep existing list stock actions available.
- Add focused acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Changing inventory list row layout.
- Removing list stock actions.
- Redesigning stock adjustment, stock usage, or history screens.

## Requirements

- Inventory detail must expose edit directly from the top toolbar.
- Inventory detail must expose history, use, and adjust actions from a top toolbar more menu.
- Edit must continue to open item edit mode.
- History must open stock history for the selected item.
- Use must open stock consumption for the selected item.
- Adjust must open stock adjustment for the selected item.
- Existing inventory list stock actions must continue to work.

## Design

`InventoryItemDetailView` owns local presentation state for the action sheets it can open from
detail. The toolbar keeps edit as a direct pencil action and groups secondary stock actions under
a more menu:

- `pencil`,
- `ellipsis.circle`.

Inside the menu, the owner can choose Adjust Stock, Use Stock, or View History. This keeps the
inventory list dense and stable, keeps the detail toolbar calm, and still makes item-specific
actions discoverable after the owner taps into the item.

RFC-0069 later moved active inventory rows to card-based styling. The same list stock actions are
now visible row action chips rather than list-row swipe actions.

## Tests

Acceptance coverage:

- owner creates inventory,
- opens inventory item detail,
- sees edit and more actions,
- opens Adjust Stock from the more menu,
- opens Use Stock from the more menu,
- opens Stock History from the more menu.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner can reach stock actions from inventory detail without swiping on the list row.
