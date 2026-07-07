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

## Superseding Note

RFC-0070 moved inventory detail stock actions from a top toolbar more menu into visible detail
action chips below the hero card. The owner-facing capability remains the same, but current UI
truth should follow RFC-0070.

## Scope

- Replace the text Edit action in inventory detail with a pencil icon action.
- Add an inventory detail action area for:
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
- Inventory detail must expose history, use, and adjust actions from the detail screen.
- Edit must continue to open item edit mode.
- History must open stock history for the selected item.
- Use must open stock consumption for the selected item.
- Adjust must open stock adjustment for the selected item.
- Existing inventory list stock actions must continue to work.

## Design

`InventoryItemDetailView` owns local presentation state for the action sheets it can open from
detail. The current RFC-0070 UI keeps edit as a direct pencil action and exposes secondary stock
actions as visible detail action chips for Adjust Stock, Use Stock, and View History.

RFC-0069 later moved active inventory rows to card-based styling. The same list stock actions are
now visible row action chips rather than list-row swipe actions.

## Tests

Acceptance coverage:

- owner creates inventory,
- opens inventory item detail,
- sees edit and more actions,
- opens Adjust Stock from inventory detail,
- opens Use Stock from inventory detail,
- opens Stock History from inventory detail.

## Documentation

Updated:

- `README.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner can reach stock actions from inventory detail without swiping on the list row.
