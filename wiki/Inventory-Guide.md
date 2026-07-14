# Inventory Guide

Inventory is the first active CloudBake owner workflow.

## What Inventory Tracks

Inventory tracks active items with:

1. name,
2. type,
3. optional default expiry days,
4. unit,
5. current quantity,
6. minimum quantity,
7. archived state,
8. stock batches with optional expiry dates and optional amount,
9. transaction records for stock changes.

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

Perishable items are different. CloudBake hides perishable low-inventory alerts unless an active
order needs that item through a linked recipe or order-specific extra ingredients.

The app also uses local notifications for remaining stock expiring within one month after the owner
grants notification permission.

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

Each new stock quantity is tracked as a batch with an optional expiry date and optional amount.

Standard inventory defaults to having an expiry date one month from the add or adjustment date, but
the owner can turn expiry off before saving. Perishable inventory defaults the expiry date to four
days from the add or adjustment date.

An item can instead define its own positive whole-number default expiry days. That value applies to
future initial stock, adjustments, and matched purchase-bill drafts. It does not rewrite existing
batches, and the owner can still change or remove an individual batch expiry.

When newer stock is added for the same item, the app combines it into an existing batch only when
the expiry date and amount are the same. If the expiry date or amount differs, the app keeps a
separate batch.

When stock is used, the app deducts from the oldest-expiring batch first. After that batch reaches
zero, usage continues into the next oldest batch.

Expiry reminders are local to the device. The reminder message names the item, remaining batch
quantity, unit, and expiry date. Expired batches, empty batches, no-expiry batches, and batches
expiring later than one month are not scheduled for expiry reminder notifications.

Expiry reminders are scheduled once per day at 9 AM. If CloudBake refreshes reminders after that
day's 9 AM reminder time, it schedules the next reminder for 9 AM on the following day when the
batch is still eligible.

## Inventory Detail

Tap an inventory row to inspect the item before changing it.

The detail view shows:

1. name,
2. type,
3. unit,
4. current quantity,
5. minimum quantity,
6. remaining stock batches with quantity, amount, and expiry date.

Use the expiry table to see how much stock expires on each date.

Tap a stock batch row from the expiry table to correct that batch's quantity, amount, or expiry
date. Use the visible delete action to delete a mistaken batch.

## Duplicate Warning

When adding inventory, the app checks for same or similar names before creating another item.

This is meant to avoid accidental duplicates. The owner can still intentionally add a duplicate if
the warning is reviewed and accepted.

## Inventory Aliases

Inventory aliases are alternate bill names for an ingredient or supply.

Use aliases when receipts use brand names, abbreviations, or local names that differ from the
inventory name. For example, an inventory item named `Cake Flour` can have aliases such as `Maida`,
`Aashirvaad Maida`, or `Plain Flour`.

Aliases are edited from the inventory add/edit form. Separate multiple aliases with commas or new
lines. CloudBake removes blank aliases and duplicate aliases before saving.

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

The parser reads bill text line by line, keeps only lines that match the baking catalog or an active
inventory item's name or aliases, and captures common quantity/unit pairs such as `1 kg`, `500g`,
`250 ml`, `12 pcs`, `2 tsp`, or `1 cup`.

The owner can open Import Bill, take a purchase bill photo, retake the photo, or choose an existing
bill image from the photo library. The app reads the selected image using local Vision OCR and
parses the recognized text into draft inventory rows.

The selected bill image is previewed in the import flow so the owner can quickly spot the wrong
photo before saving drafts.

The owner can review draft items before saving. Draft review supports selecting which items to save,
editing recognized text, names, quantities, units, minimum quantities, and expiry dates.

When a draft matches an existing active inventory item, CloudBake adds the draft quantity to that
existing item and creates a new stock batch with the draft expiry date. Compatible units are
converted first, such as `1 kg` on the bill becoming `1000 g` for an item stored in grams.

When bill text matches an inventory alias, the draft uses the saved inventory item name so saving the
draft updates that item.

Drafts that do not match existing inventory create normal inventory items and initial stock batches.
Manual recognized text entry remains available as a fallback when a bill photo cannot be read
clearly.

## Add Inventory By Voice

Use Add Inventory by Voice to speak several item, quantity, and unit phrases, such as
`flour 800 grams, strawberry 100 grams`. Recognition runs on the iPhone in the current iPhone
language; CloudBake does not upload the audio or transcript and does not fall back to server speech
recognition. Manual transcript editing remains available when listening is unavailable.
Edits made while listening become the baseline for later speech, so recognition updates do not
restore text that the owner already corrected.

Create Drafts turns complete phrases into editable inventory rows. A unique exact saved inventory
name or alias matches automatically; partial and ambiguous matches require a decision. For an
unknown spoken item, choose whether to map it to searchable, unit-compatible existing inventory or
create new inventory. Mapping also saves the spoken name as an alias for future recognition.
Review quantity, unit, and expiry before saving. Minimum quantity is requested for new inventory;
mapped drafts retain the saved item's minimum quantity. One save commits all drafts and stock
batches together or leaves inventory unchanged if any part fails.

## Stock Adjustment

Use adjustment to increase stock and keep a transaction record.

Adjustment examples:

1. bought 5 kg flour,
2. added 2 cups cocoa powder,
3. corrected stock upward after counting.

The adjustment unit defaults to the item's unit, but the owner can choose another compatible unit.
For example, a flour item stored in grams can be adjusted by entering kg.

The owner can enter an optional amount for the added stock. If the amount and expiry date
match an existing batch for the same item, CloudBake combines the quantities. If either value
differs, CloudBake keeps a separate batch.

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

Consumption also updates stock batches. Expired batches cannot be consumed. Among the remaining
usable batches, the oldest-expiring stock is reduced before newer stock. If usable stock cannot
cover the requested quantity, CloudBake stops the consumption and explains that non-expired stock
is insufficient.

## Dispose Expired Stock

Open an inventory item and use the trash action beside Expiry to dispose of all remaining expired
stock. CloudBake asks for confirmation, clears only expired batches, preserves usable stock, and
records the change as Expired Disposal in stock history.

Expired disposal is for stock that was discarded. Use batch correction instead when the saved
quantity or expiry date was entered incorrectly.

## Stock Batch Editing

Open an inventory item to review its remaining stock batches. Selecting a batch allows the owner to
edit remaining quantity, amount, and expiry date.

Changing a batch quantity also updates the inventory item's current quantity by the same difference.
For example, changing a flour batch from `250 g` to `300 g` increases current stock by `50 g`.

Deleting a stock batch removes that batch from the expiry table and reduces current quantity by the
deleted batch quantity. This is a correction workflow for mistaken batches, not normal stock usage.

## Stock History

Use stock history to review why an active inventory item's quantity changed.

History shows adjustment, consumption, and expired-disposal records newest first. Adjustments
display as stock added, consumption as stock used, and expired disposal as expired stock removed.

## Archive And Restore

Archive inventory when it should not appear in the active list.

CloudBake asks for confirmation before moving an item out of the active inventory list.

Restore archived inventory when the owner needs to use it again.

Archive is preferred over delete because inventory history can matter later.

## Import And Export CSV

Open Settings to import or export inventory CSV.

CSV export includes active inventory items and their stock batches. Each row includes:

1. name,
2. aliases,
3. inventory type,
4. default expiry days,
5. unit,
6. current quantity,
7. minimum quantity,
8. batch quantity,
9. amount,
10. expiry date.

CSV import creates new active inventory items or updates matching active items by name and unit.
When updating an existing item, CloudBake replaces that item's saved stock batches with the imported
batches, aliases, inventory type, and default expiry days, then recalculates current quantity from
the imported batch quantities. The CSV must include the `aliases`, `type`, and
`default_expiry_days` headers. Type accepts `Standard` or `Perishable`; default expiry days accepts
a blank value or a positive whole number.

Use stock adjustment for normal day-to-day stock changes. Use CSV import when moving inventory data
in bulk or making a deliberate correction from a reviewed file.

## Not Yet Supported

Inventory does not yet support:

1. ingredient-density conversion between weight and volume,
2. in-app baking catalog editing,
3. inventory delete,
4. supplier tracking,
5. purchase planning,
6. editing unit, current quantity, or expiry from item edit mode,
7. CSV conflict review before import replacement.
