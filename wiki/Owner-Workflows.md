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

Recipe usage from an order can now deduct linked ingredient rows from inventory. Recipe scaling,
stronger OCR cleanup, richer component grouping, and optional LLM-assisted interpretation remain
future work.

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

## Review Order Reminders

Order detail shows the next relevant reminder from the three-day, two-day, and one-day reminder
plan.

When notification permission is granted, CloudBake schedules local owner notifications for
Confirmed, In Progress, and Ready orders at future three-day, two-day, and one-day reminder times.
Draft, Completed, Cancelled, past-due, and already-missed reminders are not scheduled.

Reminder snooze, configurable offsets, day-of reminders, and calendar integration remain future
work.

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

## Order Workflow

Use Orders to track accepted or draft cake work from enquiry through delivery. `docs/rfc/orders.md`
is the base product RFC for this area.

Today, the owner can:

1. view active orders grouped by delivery or pickup day,
2. add an order,
3. search and link an order to an existing customer record when useful,
4. enter a customer name directly for quick drafts,
5. capture due date and time,
6. choose draft or confirmed status,
7. choose pickup or delivery,
8. capture optional delivery address,
9. capture cake notes,
10. view order detail,
11. edit order details from the detail screen,
12. manually change order status across Draft, Confirmed, In Progress, Ready, Completed, and
    Cancelled,
13. review linked customer allergies, dietary restrictions, likes, dislikes, and notes from order
    detail,
14. link an order to one saved recipe for preparation context,
15. review the linked recipe name from order detail,
16. change order status from detail without opening the full edit form,
17. mark a Confirmed order Ready or Completed from detail or edit order and deduct linked recipe
    ingredients from inventory with unit conversion,
18. add, complete, and delete simple preparation checklist items from order detail,
19. review completed and cancelled orders in a separate Completed tab,
20. use row swipe actions to change status or record payment,
21. mark payment Paid or add a partial payment from order detail,
22. review the next relevant reminder in order detail,
23. add customer reference photos and final cake photos from the camera or photo library,
24. review and delete saved order photos from order detail.

Active orders are grouped by due day, with orders inside each day ordered by delivery or pickup time
ascending. Completed and cancelled orders are kept out of active work and appear in a simple
Completed tab ordered by delivery or pickup date-time descending. Cancelled rows show a small red
indicator so they are not mistaken for fulfilled work.

On iPad, Orders uses a list/detail layout: the order list stays visible while selected order detail
appears in the detail column. On iPhone, order detail continues to open as a focused sheet.

The Orders screen no longer has a standalone Reminders Due section. Order detail shows the next
reminder for that cake. Completed and cancelled orders do not appear in due reminder calculations.
Confirmed, In Progress, and Ready orders also schedule local owner notifications for future
three-day, two-day, and one-day reminder times. Snooze, configurable reminder offsets, day-of
reminders, and calendar integration are future work.

Customer record selection opens from the order form. The owner can search customers by name, phone,
email, or address, select a saved customer, or clear the link and keep manually entered order text.

Linked customer details remain owner-facing context. The order keeps a customer name snapshot for
the order itself, while allergies and longer-term preferences continue to come from the customer
record.

Recipe selection opens from the order form when saved recipes exist. The owner can link one saved
recipe, clear the link, and review the linked recipe from order detail.

Design selection opens from the order form when saved cake designs exist. The owner can link one
existing design reference, clear the link, and review the linked design name, notes, and photo
reference from order detail.

Order detail also includes a Photos section for order-specific images. Customer References are for
images the customer shares before preparation, while Final Cake Photos are for what the owner made
and delivered. The owner can add either kind from the camera or photo library and delete mistaken
photo rows. Full-screen preview, caption editing, and promoting final cake photos into the design
library remain future work.

When a Confirmed order with an unused linked recipe is marked Ready or Completed from order detail,
the app asks for confirmation and then deducts the recipe's inventory-backed ingredient rows. When
the same status transition is saved through edit order, the app uses the same one-time deduction
rule.
Quantities are converted into each inventory item's unit when compatible. Stock batches are consumed
oldest-expiry-first, and the usage can be recorded only once for the order to prevent accidental
double deduction.

Order detail includes a Checklist section for owner preparation tasks such as crumb coat, topper
pickup, box ready, or final photo. The owner can add checklist items and tap any checklist row to
mark it complete or incomplete. Checklist items stay in entry order and can be deleted from order
detail. Checklist editing, reordering, templates, and checklist-driven status changes are future
work.

Order add/edit includes a Pricing And Payment section for the owner-entered quoted price, deposit
paid, and payment notes. Order detail shows payment status, quoted price, deposit paid, and derived
balance due. From order detail, the owner can mark the order Paid or add a partial payment without
opening full edit. Marking Paid sets the paid amount to the quoted price and makes balance due zero.
Adding a partial payment asks for the newly received amount and adds it to the existing paid amount.

Order rows also expose swipe actions for quick status changes and payment recording. These quick
actions use centered popups and ask for confirmation before saving. Pricing suggestions,
recipe-cost calculation, discounts, refunds, and online payment processing remain future work.

Future order slices should add order photo preview and caption editing, reminder snooze, recipe
scaling, partial recipe usage, and richer order photo/design library workflows.

## Customer Workflow

Use Customers to remember customer name, address, phone, important dates, likes, dislikes,
allergies, dietary restrictions, and order history. `docs/rfc/customers.md` is the base product RFC
for this area.

Today, the owner can add customers manually or start from an Apple Contacts import draft. Contacts
import is owner initiated, copies one selected contact into the add form, and does not save anything
until the owner reviews the draft and taps Save.

Name and phone are required. Address, email, important dates, likes, dislikes, allergies, dietary
restrictions, and notes are optional.

Customer edit updates contact details and preference fields. Important date correction is future
work.

The app warns before saving when a new customer looks like a duplicate. Contacts import can prefill
contact details, but CloudBake-specific preferences and allergy notes remain owner-entered.

Orders can link to customer records today. Linked order detail surfaces saved customer preferences
and allergy details for owner review. Customer detail also shows linked orders in due-date order so
the owner can review a customer's cake history from the customer record. Order add/edit uses a
searchable customer selection flow so saved customers remain usable as the list grows.

On iPad, Customers uses a list/detail layout: the customer list stays visible while selected
customer contact details, preferences, important dates, and linked order history appear in the
detail column. On iPhone, customer detail continues to open as a focused sheet.

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
