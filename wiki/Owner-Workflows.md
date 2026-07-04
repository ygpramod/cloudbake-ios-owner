# Owner Workflows

This page describes how the owner should think about app workflows.

## Inventory Workflow

The owner can use inventory to answer:

1. what do I have,
2. how much do I have,
3. what is running low,
4. did I add stock,
5. did I use stock,
6. should an old item be hidden or restored.

Today, inventory changes are manual. Recipe-driven stock reduction is future work.

## Add Inventory

Use add inventory when a new ingredient or supply needs to be tracked.

Before adding, the app warns when an existing item has the same or similar name. This helps avoid
duplicates like multiple cake flour rows.

## Edit Inventory

Use edit inventory when the item name, unit, current quantity, or minimum quantity needs correction.

Editing is for correcting the item record. Stock movement should usually be represented by
adjustment or consumption when the reason matters.

## Adjust Stock

Use stock adjustment when stock increases.

Examples:

1. bought more flour,
2. received more butter,
3. corrected stock after counting and found extra quantity.

The app updates current quantity and records an adjustment transaction.

## Use Stock

Use stock consumption when stock decreases manually.

Examples:

1. used flour for a cake,
2. used buttercream supplies,
3. corrected stock after counting and found less quantity.

The app rejects usage greater than current stock so inventory does not go below zero.

## Archive Inventory

Use archive when an item should not appear in the active inventory list anymore.

Examples:

1. the owner stopped using an ingredient,
2. a supplier item changed,
3. an old packaging size is no longer used.

Archived items can be restored.

## Dashboard Workflow

Use the dashboard to quickly see inventory that needs attention.

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
