# Owner Workflows

This page describes how the owner should think about app workflows.

## Inventory Workflow

The owner can use inventory to answer:

1. what do I have,
2. how much do I have,
3. what is running low,
4. did I add stock,
5. did I use stock,
6. what stock expires first,
7. should an old item be hidden or restored.

Today, inventory changes are manual. Recipe-driven stock reduction is future work.

## Recipe Workflow

Use Recipes to start moving trusted cake recipes from the owner's book into CloudBake.

The current recipe workflow stores:

1. recipe name,
2. owner notes,
3. linked ingredient rows with inventory item, quantity, unit, and optional note.

The owner can also import a recipe from paper or a recipe book by taking a photo, retaking the
photo, choosing an image from the photo library, or manually entering recognized text. The app reads
the image locally with Apple Vision OCR, creates an editable draft, parses likely ingredient rows,
and saves it only after the owner reviews it.

Recipe scaling, stronger OCR cleanup, richer component grouping, optional LLM-assisted
interpretation, and recipe-driven inventory reduction are future work.

## Recipe Ingredients

Tap a recipe to view its detail.

Recipe detail shows notes and ingredient rows. Each ingredient row is linked to an active inventory
item and stores the quantity, unit, and optional preparation note needed for that recipe.

Use the edit action in recipe detail when the recipe name or notes need correction.

Use Add Ingredient when the owner wants to manually define the stock needed by a recipe. Tap an
ingredient row to edit it, or swipe to delete a mistaken row.

Recipe ingredient rows do not reduce inventory yet. They prepare the app for a future Use Recipe
flow that will deduct stock from oldest-expiring batches first.

## Import Recipe Review

Recipe import is a review workflow.

When recognized text contains lines like `Flour - 250 g` or `BP - 1/2 tsp`, the app turns them into
draft ingredient rows. The owner can edit the ingredient name, quantity, unit, inventory item link,
and note before saving.

Imported ingredient rows must be linked to inventory items before save. Lines that do not look like
ingredients are kept as recipe notes.

## Add Inventory

Use add inventory when a new ingredient or supply needs to be tracked.

Before adding, the app warns when an existing item has the same or similar name. This helps avoid
duplicates like multiple cake flour rows.

When starting quantity is entered, the owner also captures an expiry date for that starting stock.

## View Inventory

Tap an inventory row to view the item.

The view mode shows name, unit, current quantity, minimum quantity, and an expiry table. The expiry
table lists each remaining stock batch by quantity and expiry date.

The detail toolbar exposes a direct edit action and a more menu for history, use stock, and adjust
stock, so the owner does not need to return to the list and swipe for common item work.

Tap a batch in the expiry table when that batch's quantity or expiry date needs correction. Swipe a
batch when a mistaken batch should be deleted.

## Edit Inventory

Use edit inventory when the item name or minimum quantity needs correction.

Editing is reached from the inventory detail view.

Current quantity should be changed through stock adjustment or stock consumption. Unit and item-level
expiry are not edited from item edit mode.

## Adjust Stock

Use stock adjustment when stock increases.

Examples:

1. bought more flour,
2. received more butter,
3. corrected stock after counting and found extra quantity.

The app updates current quantity and records an adjustment transaction.

The adjustment unit defaults to the item's unit. The owner can choose another compatible unit, such
as kg for a flour item stored in grams or liters for a cream item stored in ml.

Each adjustment also captures an expiry date and creates a separate stock batch. This keeps older
and newer stock distinct when their expiry dates differ.

## Use Stock

Use stock consumption when stock decreases manually.

Examples:

1. used flour for a cake,
2. used buttercream supplies,
3. corrected stock after counting and found less quantity.

The app rejects usage greater than current stock so inventory does not go below zero.

The usage unit defaults to the item's unit. The owner can choose another compatible unit before
saving, and the app converts the entry back to the item's stored unit.

When stock is used, the app deducts from the oldest-expiring batch first and then moves into newer
batches.

## Review Expiry Reminders

When notification permission is granted, CloudBake schedules local reminders for remaining stock
batches expiring within one month. These reminders are refreshed when the app opens or returns to
the foreground.

The reminder names the inventory item, remaining quantity, unit, and expiry date.

## Correct Stock Batches

Use stock batch correction when a remaining batch was entered incorrectly.

The owner can edit a batch quantity or expiry date from inventory detail. Deleting a batch removes
it and reduces the inventory item's current quantity by the deleted amount.

Batch correction is different from stock usage. Use stock usage when stock was actually consumed;
use batch correction when the saved data is wrong.

## Import Purchase Bills

Use Import Bill when newly purchased baking stock should become inventory drafts.

The owner can take a bill photo, retake the photo, or choose an existing bill image from the photo
library. The selected image is previewed, read locally with Apple Vision OCR, and turned into
editable draft inventory rows.

Manual bill text entry remains available when an image is unclear.

## Review Stock History

Use stock history when the owner needs to understand why an item's quantity changed.

The history includes manual stock adjustments and manual stock usage for the selected inventory
item. This is useful before recipe-driven stock changes exist, and it becomes more important once
recipes start reducing inventory automatically.

## Archive Inventory

Use archive when an item should not appear in the active inventory list anymore.

Examples:

1. the owner stopped using an ingredient,
2. a supplier item changed,
3. an old packaging size is no longer used.

Archived items can be restored.

## Dashboard Workflow

Use the dashboard to quickly see inventory that needs attention.

Dashboard low inventory includes items below minimum quantity, items with expired remaining stock,
and items with remaining stock expiring within one month.

The dashboard is expected to become more useful as orders, reminders, and recipes are added.

## Future Order Workflow

Future order workflow should help the owner track:

1. customer,
2. cake type,
3. flavor,
4. design reference,
5. due date,
6. delivery date,
7. reminders three days, two days, and one day before delivery.

## Future Pricing Workflow

Future pricing should help calculate a suggested price, but the final input must remain owner
controlled.

Possible pricing inputs:

1. ingredients,
2. size,
3. servings,
4. time,
5. design complexity,
6. packaging,
7. delivery,
8. owner override.
