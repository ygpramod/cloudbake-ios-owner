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

An inventory item has a name, unit, current quantity, minimum quantity, and stock batches.

## Stock Batch

A stock batch is one portion of an inventory item with its own remaining quantity and expiry date.

Example:

1. cake flour, 500 g, expires July 15,
2. cake flour, 1000 g, expires August 10.

These are the same inventory item but different stock batches. This matters because handmade cake
work needs the older stock to be used before newer stock.

## Expiry Date

Expiry date is captured for new stock when inventory is added or adjusted upward. The owner can
correct a stock batch quantity or expiry date from inventory detail.

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

## Low Inventory

Low inventory means the owner should consider restocking.

Low inventory is calculated from current quantity, minimum quantity, remaining expired stock, and
stock expiring within one month. It is not manually assigned.

An item can be low inventory even when current quantity is above minimum if any remaining stock has
expired or is close to expiry.

## Inventory Transaction

An inventory transaction records why stock changed.

Current transaction types:

1. adjustment: stock was added,
2. consumption: stock was used.

Transaction quantities are stored as positive numbers. The transaction type carries the meaning.

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

## Recipe

A recipe describes the ingredients and steps needed to make a cake or component.

The current app can store recipe names, owner notes, and linked ingredient rows. Each ingredient row
points to an inventory item and records quantity, unit, and optional note. The app can also use
local Apple Vision OCR to turn a paper or book recipe image into an editable recipe draft with
structured ingredient rows.

When an order links to a saved recipe, marking the Confirmed order Ready or Completed records one
usage event for the order and deducts ingredient quantities from inventory using compatible unit
conversion and oldest-expiry-first stock batches. Future recipe work should add
stronger OCR cleanup, richer component grouping, method details, scaling, and optional LLM-assisted
interpretation.

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

## Baking Catalog

The baking catalog is a curated list of items that matter to baking workflows.

Each catalog item has a name, aliases, category, and active flag. Examples include cake flour,
butter, whipping cream, cocoa powder, fondant, cake boards, and cake boxes.

Purchase bill scanning uses this catalog to decide which bill lines become draft inventory items.
Non-baking household or grocery lines should be ignored unless the owner adds them to the catalog.

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

## Owner Price

The app may help suggest pricing from ingredients, time, size, and complexity, but the owner decides
the final price.

Handmade cake pricing requires business judgment.
