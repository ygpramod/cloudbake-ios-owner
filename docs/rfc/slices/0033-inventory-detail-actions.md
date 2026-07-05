# Slice RFC-0033: Inventory Detail Actions

## Status

Accepted

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Make common stock actions visible from the inventory item detail screen.

## Scope

- Replace the text Edit action in inventory detail with a pencil icon action.
- Add visible inventory detail toolbar actions for:
  - history,
  - use stock,
  - adjust stock.
- Keep existing list swipe actions unchanged.
- Add focused acceptance coverage.
- Update README and wiki source.

## Out Of Scope

- Changing inventory list row layout.
- Removing swipe actions.
- Redesigning stock adjustment, stock usage, or history screens.

## Requirements

- Inventory detail must expose edit, history, use, and adjust actions from the top toolbar.
- Edit must continue to open item edit mode.
- History must open stock history for the selected item.
- Use must open stock consumption for the selected item.
- Adjust must open stock adjustment for the selected item.
- Existing inventory list swipe actions must continue to work.

## Design

`InventoryItemDetailView` owns local presentation state for the action sheets it can open from
detail. The toolbar uses icon-backed `Label` buttons for:

- `pencil`,
- `clock`,
- `minus`,
- `plusminus`.

This keeps the inventory list dense and stable while making item-specific actions visible after the
owner taps into the item.

## Tests

Acceptance coverage:

- owner creates inventory,
- opens inventory item detail,
- sees edit, history, use, and adjust actions,
- adjust opens Adjust Stock,
- use opens Use Stock,
- history opens Stock History.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner can reach stock actions from inventory detail without swiping on the list row.
