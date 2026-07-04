# Slice RFC-0017: Inventory Unit Conversion

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0002-mobile-persistence-sqlite-grdb.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Allow the owner to enter stock adjustments and stock usage in a compatible measurement unit while
keeping inventory stored in the item's own unit.

## Scope

- Add domain-level conversion for supported inventory units.
- Add liters as a supported volume unit.
- Default stock adjustment and stock usage units to the inventory item's unit.
- Allow compatible alternate units in stock adjustment and stock usage flows.
- Convert entered quantities into the inventory item's unit before saving inventory totals,
  transaction records, and stock batch quantities.
- Keep oldest-expiry-first stock consumption working after conversion.
- Add focused unit tests for conversion and view-model behavior.
- Update owner wiki product pages for the visible unit behavior.

## Out of Scope

- Recipe-driven automatic inventory reduction.
- Ingredient-density conversion between weight and volume, such as cups of flour to grams.
- Changing an existing inventory item's canonical unit.
- Storing both entered unit and converted unit on inventory transactions.
- Acceptance UI coverage for every conversion pair.

## Requirements

- The adjustment unit defaults to the selected inventory item's unit.
- The consumption unit defaults to the selected inventory item's unit.
- Weight units convert between kg and grams.
- Volume units convert between liters, ml, teaspoons, tablespoons, and cups.
- Count units only convert from each to each.
- Incompatible unit conversion must not change inventory.
- Inventory totals, stock batches, and transaction quantities remain stored in the inventory item's
  unit after conversion.

## Design

### Domain

`InventoryUnit` owns conversion behavior so stock adjustment, stock consumption, recipes, and future
pricing can use the same source of truth.

Supported conversion factors:

- 1 kg = 1000 g
- 1 L = 1000 ml
- 1 tsp = 5 ml
- 1 tbsp = 15 ml
- 1 cup = 240 ml

The model exposes compatible units by measurement family. Weight, volume, and count are intentionally
separate because converting across those families requires ingredient-specific density.

### View Model

`InventoryListViewModel` adds draft units for adjustment and consumption.

Before saving, the view model converts the entered quantity into the inventory item's unit. The
converted quantity is used for:

- `InventoryItem.currentQuantity`,
- `InventoryTransaction.quantity`,
- `InventoryStockBatch.remainingQuantity`,
- batch consumption math.

### UI

The stock adjustment and stock consumption forms show a unit picker after the quantity field. The
picker is limited to units compatible with the selected inventory item's stored unit.

## Test Plan

- Unit tests:
  - Weight units convert between kg and grams.
  - Volume units convert between liters, ml, teaspoons, tablespoons, and cups.
  - Cross-family conversion returns no conversion.
  - Stock adjustment converts the draft unit before updating item, transaction, and batch values.
  - Stock consumption converts the draft unit before validating current stock and deducting batches.

- Integration tests:
  - Existing inventory persistence tests continue to cover persisted canonical quantities.

- Acceptance tests:
  - No new acceptance journey is required for this slice. The behavior is covered by domain and
    view-model tests, and the existing owner inventory journey continues to exercise adjustment,
    consumption, and history surfaces.

## Acceptance Criteria

- Owner can adjust a gram-based item using kg and see stored stock increase in grams.
- Owner can consume an ml-based item using liters and see stored stock decrease in ml.
- Stock batch deduction still consumes oldest-expiring batches first after unit conversion.
- The app does not offer incompatible units in adjustment or consumption forms.
- Tests pass locally and in CI.
