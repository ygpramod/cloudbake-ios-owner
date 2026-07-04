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
2. ml,
3. grams,
4. teaspoons,
5. tablespoons,
6. cups.

When future recipe conversion is added, unit handling must be careful because handwritten or book
recipes may use mixed units.

## Low Inventory

An item is low inventory when current quantity is below minimum quantity or when it has expired
remaining stock.

Example:

1. current quantity: 500 g,
2. minimum quantity: 1000 g,
3. result: low inventory.

Expiry example:

1. current quantity: 2000 g,
2. minimum quantity: 1000 g,
3. remaining batch expired yesterday,
4. result: low inventory.

## Stock Batches And Expiry

Each new stock quantity is tracked as a batch with its own expiry date.

When newer stock is added for the same item, the app keeps both batches. It does not merge them into
one quantity if the expiry dates differ.

When stock is used, the app deducts from the oldest-expiring batch first. After that batch reaches
zero, usage continues into the next oldest batch.

## Duplicate Warning

When adding inventory, the app checks for same or similar names before creating another item.

This is meant to avoid accidental duplicates. The owner can still intentionally add a duplicate if
the warning is reviewed and accepted.

## Stock Adjustment

Use adjustment to increase stock and keep a transaction record.

Adjustment examples:

1. bought 5 kg flour,
2. added 2 cups cocoa powder,
3. corrected stock upward after counting.

## Stock Consumption

Use consumption to reduce stock and keep a transaction record.

Consumption examples:

1. used 500 g flour,
2. used 250 ml cream,
3. corrected stock downward after counting.

The app does not allow consumption greater than current stock.

Consumption also updates stock batches. The oldest-expiring remaining stock is reduced before newer
stock.

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
2. unit conversion,
3. inventory delete,
4. supplier tracking,
5. purchase planning,
6. editing individual stock batches directly,
7. expiry reminder notifications.
