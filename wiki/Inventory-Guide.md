# Inventory Guide

Inventory is the first active CloudBake owner workflow.

## What Inventory Tracks

Inventory tracks active items with:

1. name,
2. unit,
3. current quantity,
4. minimum quantity,
5. archived state,
6. stock batches with expiry dates,
7. transaction records for stock changes.

## Units

The product should support practical bakery units.

Important units from the owner workflow:

1. kg,
2. liters,
3. ml,
4. grams,
5. teaspoons,
6. tablespoons,
7. cups.

Stock adjustment and stock consumption can be entered in compatible units. The app stores inventory
in the item's own unit after conversion.

Conversion is supported within the same measurement family:

1. kg and grams,
2. liters, ml, teaspoons, tablespoons, and cups,
3. each only to each.

The app does not convert between weight and volume because that requires ingredient-specific
density, such as flour grams per cup.

## Low Inventory

An item is low inventory when current quantity is below minimum quantity, when it has expired
remaining stock, or when remaining stock expires within one month.

Example:

1. current quantity: 500 g,
2. minimum quantity: 1000 g,
3. result: low inventory.

Expiry example:

1. current quantity: 2000 g,
2. minimum quantity: 1000 g,
3. remaining batch expires within one month,
4. result: low inventory.

## Stock Batches And Expiry

Each new stock quantity is tracked as a batch with its own expiry date.

When newer stock is added for the same item, the app keeps both batches. It does not merge them into
one quantity if the expiry dates differ.

When stock is used, the app deducts from the oldest-expiring batch first. After that batch reaches
zero, usage continues into the next oldest batch.

## Inventory Detail

Tap an inventory row to inspect the item before changing it.

The detail view shows:

1. name,
2. unit,
3. current quantity,
4. minimum quantity,
5. remaining stock batches with quantity and expiry date.

Use the expiry table to see how much stock expires on each date.

Tap a stock batch row from the expiry table to correct that batch's expiry date.

## Duplicate Warning

When adding inventory, the app checks for same or similar names before creating another item.

This is meant to avoid accidental duplicates. The owner can still intentionally add a duplicate if
the warning is reviewed and accepted.

## Baking Catalog

The baking catalog is a JSON config that lists ingredients, decorations, and packaging that are
relevant to baking.

The catalog includes names, aliases, categories, and an active flag. It is used as the foundation
for future purchase bill scanning, where the app should draft inventory only for baking-related
bill lines.

Today the catalog is bundled with the app as `BakingCatalog.json`. Future slices can add an owner
editing screen or a local editable copy.

## Purchase Bill Drafts

Purchase bill draft parsing turns recognized bill text into inventory draft candidates.

Bill text recognition uses Apple's local Vision OCR framework. Receipt images do not need to leave
the device for the first version, and there is no OCR subscription or per-scan service fee.

The parser reads bill text line by line, keeps only lines that match the baking catalog, and captures
common quantity/unit pairs such as `1 kg`, `500g`, `250 ml`, `12 pcs`, `2 tsp`, or `1 cup`.

The owner can open Import Bill, take a purchase bill photo, and let the app read the bill text using
local Vision OCR. The recognized text is parsed into draft inventory rows.

The owner can review draft items before saving. Draft review supports selecting which items to save,
editing recognized text, names, quantities, units, minimum quantities, and expiry dates.

When a draft matches an existing active inventory item, CloudBake adds the draft quantity to that
existing item and creates a new stock batch with the draft expiry date. Compatible units are
converted first, such as `1 kg` on the bill becoming `1000 g` for an item stored in grams.

Drafts that do not match existing inventory create normal inventory items and initial stock batches.
Manual recognized text entry remains available as a fallback when a bill photo cannot be read
clearly.

## Stock Adjustment

Use adjustment to increase stock and keep a transaction record.

Adjustment examples:

1. bought 5 kg flour,
2. added 2 cups cocoa powder,
3. corrected stock upward after counting.

The adjustment unit defaults to the item's unit, but the owner can choose another compatible unit.
For example, a flour item stored in grams can be adjusted by entering kg.

## Stock Consumption

Use consumption to reduce stock and keep a transaction record.

Consumption examples:

1. used 500 g flour,
2. used 250 ml cream,
3. corrected stock downward after counting.

The app does not allow consumption greater than current stock.

The consumption unit defaults to the item's unit, but the owner can choose another compatible unit.
For example, a cream item stored in ml can be used by entering liters, tablespoons, teaspoons, or
cups.

Consumption also updates stock batches. The oldest-expiring remaining stock is reduced before newer
stock.

## Stock Batch Editing

Open an inventory item to review its remaining stock batches. Selecting a batch allows the owner to
edit both remaining quantity and expiry date.

Changing a batch quantity also updates the inventory item's current quantity by the same difference.
For example, changing a flour batch from `250 g` to `300 g` increases current stock by `50 g`.

## Stock History

Use stock history to review why an active inventory item's quantity changed.

History shows adjustment and consumption records newest first. Adjustments display as stock added.
Consumption displays as stock used.

## Archive And Restore

Archive inventory when it should not appear in the active list.

Restore archived inventory when the owner needs to use it again.

Archive is preferred over delete because inventory history can matter later.

## Not Yet Supported

Inventory does not yet support:

1. recipe-driven automatic reduction,
2. ingredient-density conversion between weight and volume,
3. in-app baking catalog editing,
4. inventory delete,
5. supplier tracking,
6. purchase planning,
7. deleting stock batches,
8. editing unit, current quantity, or expiry from item edit mode,
9. expiry reminder notifications.
