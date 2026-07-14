# Business Concepts

This page defines the business language used by the owner app.

## Inventory Item

An inventory item is an ingredient or supply the owner wants to track.

Examples:

1. cake flour,
2. butter,
3. sugar,
4. vanilla extract,
5. cake boxes,
6. fondant.

An inventory item has a name, type, unit, current quantity, minimum quantity, and stock batches.

Inventory type can be Standard or Perishable. Standard items are normal pantry ingredients or
supplies. Perishable items are short-life ingredients such as fruit.

## Stock Batch

A stock batch is one portion of an inventory item with its own remaining quantity, optional expiry
date, and optional amount.

Example:

1. cake flour, 500 g, expires July 15,
2. cake flour, 1000 g, expires August 10.

These are the same inventory item but different stock batches. This matters because handmade cake
work needs the older stock to be used before newer stock, and because the same ingredient can be
bought at different costs.

When added stock has the same expiry date and same amount as an existing batch, CloudBake can
combine the quantities. Different expiry dates or different amounts stay as separate batches.

## Expiry Date

Expiry date is optional for new stock when inventory is added or adjusted upward. The app defaults
expiry on, and the owner can turn it off before saving. The owner can correct a stock batch quantity
or expiry date from inventory detail.

Perishable inventory defaults new stock expiry to four days from the add or adjustment date.

The app uses expiry to warn the owner one month before expiry and to decide which batch should be
consumed first.

Expiry reminders are local notifications for remaining stock batches expiring within one month.
They help the owner use or replace handmade-cake ingredients before the expiry date.

## Current Quantity

Current quantity is how much of an inventory item is currently available.

The app uses this value to help the owner know whether enough stock is available before preparing
orders.

## Minimum Quantity

Minimum quantity is the threshold below which the owner wants to be alerted.

If current quantity is below minimum quantity, the item is treated as low inventory.

For perishable inventory, low-inventory alerts are shown only when an active order needs the item
through a linked recipe or order-specific extra ingredients.

## Low Inventory

Low inventory means the owner should consider restocking.

Low inventory is calculated from current quantity, minimum quantity, remaining expired stock, and
stock expiring within one month. It is not manually assigned.

An item can be low inventory even when current quantity is above minimum if any remaining stock has
expired or is close to expiry.

Perishable low inventory is suppressed from Dashboard and Reminders until active order demand makes
the item relevant.

CloudBake also treats an item as low inventory when usable, non-expired stock cannot cover the
combined projected demand from active orders. Projection includes scaled linked recipes and
order-specific extra ingredients. It is a warning only and does not reserve or deduct stock.

An order stops contributing projected demand after its inventory usage is recorded or when it is
Completed or Cancelled. Projection is recalculated from current data and is not historical.

## Inventory Transaction

An inventory transaction records why stock changed.

Current transaction types:

1. adjustment: stock was added,
2. consumption: usable stock was used,
3. expired disposal: expired stock was discarded.

Transaction quantities are stored as positive numbers. The transaction type carries the meaning.

Expired batches are excluded from manual and order-driven consumption. They remain in current stock
until the owner explicitly disposes of them or corrects the saved batch. Disposal clears only
expired remaining batches and preserves usable stock.

## Order Ingredient Cost

Estimated ingredient cost helps the owner quote an order. It combines the order's scaled recipe and
extra ingredients, then uses the purchase amount and quantity of usable inventory batches to derive
cost in earliest-expiry-first order. Expired batches are excluded.

When some used quantity has no saved purchase amount, CloudBake shows the total for every priced
portion and warns which ingredients still have missing prices. Missing prices are not treated as
zero.

When order inventory is deducted, CloudBake saves the actual per-ingredient cost from the batches
consumed. Later inventory price edits do not rewrite that actual cost. Deductions recorded before
ingredient costing was introduced are not backfilled.

Pre-existing batches are left without a derived unit cost because their original purchased quantity
is not available after earlier consumption. The owner can correct their amount to establish a new
cost basis. New priced purchases stay as separate batches so each purchase retains its correct unit
cost.

## Stock Batch Correction

Stock batch correction is used when a saved batch is wrong.

The owner can correct the batch quantity, correct the expiry date, or delete the batch. Deleting a
batch reduces the inventory item's current quantity by that batch's remaining quantity.

Stock batch correction is not the same as stock usage. Stock usage records real consumption; batch
correction fixes inventory data.

## Archive

Archiving hides an inventory item from the active inventory list without deleting business history.

Use archive when an item is no longer used but should remain available for historical records or
future restoration.

## Restore

Restoring moves an archived inventory item back to the active inventory list.

## Inventory CSV

Inventory CSV is an owner-controlled import/export format for active inventory and stock batches.

A CloudBake full backup is an owner-controlled disaster-recovery package. It contains the complete
private local database and referenced recovery assets, not a customer-safe export. The owner chooses
where to save it and is responsible for protecting or deleting that copy. Manual backup transport
uses the system Files picker and does not require CloudKit; restore is implemented as a separate
validated, rollback-protected workflow.

Automatic disaster-recovery backup is designed to use the owner's private CloudKit database,
retain one current validated snapshot, attempt best-effort nightly work on Wi-Fi, and catch up after
missed execution without blocking app launch. Scheduling is implemented, but live publication stays
disabled until CloudBake can bind explicit owner confirmation to the detected iCloud account. It is
backup rather than multi-device synchronization.

Cloud backup starts enabled, but the owner can disable future publication without deleting the
latest successful snapshot. Backup notifications are independently configurable and contain only
safe operational status, never private customer, recipe, cost, or photo content. A manual transfer
over cellular requires confirmation of the displayed estimated size.

It uses the columns `name`, `aliases`, `type`, `unit`, `current_quantity`, `minimum_quantity`,
`batch_quantity`, `amount`, and `expiry_date`. Aliases are comma-separated inside the CSV field,
type is Standard or Perishable, and dates use `yyyy-MM-dd`.

CSV import can create new inventory items or update matching active items by name and unit. Updating
from CSV replaces the matched item's stock batches, so it should be treated as a deliberate data
correction workflow rather than normal stock adjustment.

## Recipe CSV

Recipe CSV is an owner-editable transfer format with `name`, `recipe`, and `ingredients` columns.
The ingredients field contains pipe-separated `ingredient name:quantity:unit` values. Rows whose
name starts with `#` are documentation examples and are never imported. Ingredients resolve to
active inventory by saved name or alias; the CSV does not create inventory or change stock.

## App Currency

App currency is the owner-selected display symbol for money values in CloudBake.

The first supported symbols are `$`, `₹`, `£`, `RM`, and `S$`. Currency selection is local to the owner
app and does not perform exchange-rate conversion.

## Recipe

A recipe describes the ingredients and steps needed to make a cake or component.

The current app can store recipe names, owner notes, and linked ingredient rows. Each ingredient row
points to an inventory item and records quantity, unit, and optional note. The app can also use
local Apple Vision OCR to turn a paper or book recipe image into an editable recipe draft with
structured ingredient rows.

When an order links to a saved recipe, marking the order Ready or Completed records one
usage event for the order and deducts ingredient quantities from inventory using compatible unit
conversion and oldest-expiry-first stock batches. Order-specific extra ingredients let the owner
handle customer-specific recipe changes without changing the saved recipe; those extras are deducted
with the order's one-time recipe usage. Future recipe work should add stronger OCR cleanup, richer
component grouping, method details, scaling, and optional LLM-assisted interpretation.

Important units include kg, liters, ml, grams, teaspoons, tablespoons, and cups.

## Unit Conversion

Unit conversion lets the owner enter stock movement in a unit that is convenient at the moment while
the app stores the result in the inventory item's own unit.

Compatible conversion is supported within the same measurement family:

1. kg and grams,
2. liters, ml, teaspoons, tablespoons, and cups,
3. each only to each.

The app does not treat volume and weight as interchangeable because handmade cake ingredients need
ingredient-specific density for that conversion.

## Inventory Alias

An inventory alias is an owner-entered alternate name for an inventory item.

Aliases help purchase bill scanning recognize real receipt text, including brand names,
abbreviations, and local ingredient names. Aliases are private owner data and are used only to match
bill lines to active inventory items.

## Baking Catalog

The baking catalog is a curated list of items that matter to baking workflows.

Each catalog item has a name, aliases, category, and active flag. Examples include cake flour,
butter, whipping cream, cocoa powder, fondant, cake boards, and cake boxes.

Purchase bill scanning uses this catalog plus active inventory item names and aliases to decide
which bill lines become draft inventory items. Non-baking household or grocery lines should be
ignored unless the owner adds them to the catalog or inventory aliases.

## Purchase Bill Draft

A purchase bill draft is a proposed inventory item created from recognized purchase bill text.

Drafts are reviewed by the owner before stock changes. The owner can select draft items and correct
names, quantities, units, minimum quantities, and expiry dates before saving them into inventory.

## Purchase Bill OCR

Purchase bill OCR is the local text recognition step that extracts lines from a bill image before
draft parsing.

CloudBake uses Apple Vision for this foundation. It is on-device, does not require a separate OCR
subscription, and keeps the first version independent of LLM or cloud document analysis.

## Cake Design

A cake design is a record of a cake style the owner has made or wants to reference.

Design records can be linked to orders so the owner can see an existing design reference while
preparing a cake. The current order reference can show the design name, notes, and photo reference.

Future design records may include richer photos, flavors, decorations, colors, and customer-facing
visibility decisions.

## Customer Preference

Customer preferences include likes, dislikes, allergies, flavor choices, and design preferences.

Allergies and preferences are private owner data and must be handled carefully.

## Customer Deletion

Customer deletion removes the owner-managed customer record after confirmation.

Existing orders are not deleted. They keep their customer name snapshot and lose only the optional
link back to the deleted customer record.

## Order Checklist Item

An order checklist item is a small preparation task attached to one cake order.

Examples:

1. bake sponge,
2. crumb coat,
3. make topper,
4. pack cake box,
5. take final photo.

Checklist items help the owner track handmade preparation steps without changing the order status
automatically. They remain visible after completion so the owner can review what was done for the
order.

## Consumer Order Preview

A consumer order preview is a customer-safe summary of an owner order for future customer-facing
surfaces.

It can show cake name, customer-facing status, due date/time, fulfillment type, and safe cake design
display data. It must not expose owner-only recipe links, cake notes, private customer data,
delivery address, checklist items, inventory usage, reminders, supplier details, or pricing internals.

## Consumer Customer Profile

A consumer customer profile is a customer-safe summary of an owner customer record for future
authenticated customer-facing surfaces.

It can show customer id, display name, primary phone, and primary email. It must not expose
owner-only address details, likes, dislikes, allergies, dietary restrictions, internal notes,
timestamps, order history, supplier details, or pricing information.

## Owner Price

The app may help suggest pricing from ingredients, time, size, and complexity, but the owner decides
the final price.

Handmade cake pricing requires business judgment.
