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

Recipe usage from an order can now deduct linked ingredient rows from inventory and apply an
order-level recipe multiplier before deduction. Stronger OCR cleanup, richer component grouping,
and optional LLM-assisted interpretation remain future work.

## Recipe Ingredients

Tap a recipe to view its detail.

Recipe detail shows notes and ingredient rows. Each ingredient row is linked to an active inventory
item and stores the quantity, unit, and optional preparation note needed for that recipe.

Use the edit action in recipe detail when the recipe name or notes need correction.

Use Add Ingredient when the owner wants to manually define the stock needed by a recipe. Tap an
ingredient row to edit it, or use the visible delete action for a mistaken row.

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

Inventory type can be Standard or Perishable. Standard is the default. Perishable is for short-life
ingredients such as fruit.

When starting quantity is entered, expiry is selected by default but can be turned off before
saving. Standard inventory defaults expiry to one month from the add date. Perishable inventory
defaults the expiry date to four days from the add date.

## View Inventory

Tap an inventory row to view the item.

The active inventory list prioritizes items that need attention. Items with expired stock appear
first, then items below minimum quantity, then items expiring soon, followed by normal stock.

Use inventory search when the list grows. Search matches inventory item names and stored units while
preserving the same attention-first ordering inside the search results.

The view mode shows name, type, unit, current quantity, minimum quantity, and an expiry table. The
expiry table lists each remaining stock batch by quantity and expiry date.

The detail view exposes a direct edit action and visible action chips for history, use stock, and
adjust stock, so the owner does not need to return to the list and swipe for common item work.

Tap a batch in the expiry table when that batch's quantity or expiry date needs correction. Use the
visible delete action when a mistaken batch should be deleted.

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

Each adjustment selects an expiry date by default, can be saved without expiry when the owner turns
expiry off, and creates a separate stock batch. This keeps older and newer stock distinct when their
expiry dates differ. Perishable inventory defaults the adjustment expiry date to four days from the
adjustment date.

Each adjustment can also capture an optional amount. If the added stock has the same expiry date
and amount as an existing batch, CloudBake combines the quantities. If either differs, CloudBake
keeps a separate stock batch.

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
Expiry reminders are scheduled once per day at 9 AM; CloudBake does not send repeated same-day
catch-up notifications when the app is opened after the 9 AM reminder time.

## Review Order Reminders

Open Reminders from the dashboard to review the owner's operational reminder list in one place.
The screen shows:

1. payment due Ready or Completed orders with a reminder message, WhatsApp action, and Mark as Paid
   action,
2. orders due today with order name and customer name,
3. low inventory with item name and current/minimum quantity.

Tap an order reminder to open order detail. Tap a low-inventory reminder to open inventory item
detail.

For Payment Due, WhatsApp Reminder appears only when WhatsApp is installed. It opens WhatsApp with a
prefilled customer payment reminder using the linked customer phone number. Mark as Paid asks for
confirmation, then sets the order paid and removes the payment reminder.

Reminder order and inventory rows open their detail screens in place so the owner stays in the
Reminders workflow.

Order detail shows the next relevant reminder from the three-day, two-day, and one-day reminder
plan.

When notification permission is granted, CloudBake schedules local owner notifications for
Confirmed, In Progress, and Ready orders at future three-day, two-day, one-day, and due-time
reminder times. The due-time notification says the order was due and asks the owner to update
status. Tapping an order notification opens the matching order.

Draft, Completed, Cancelled, past-due, and already-missed reminders are not scheduled.

Reminder snooze, configurable offsets, and calendar integration remain future work.

## Switch Order Tabs

On the Orders screen, swipe right to left across the content area to move from Active to Completed,
and swipe left to right to move from Completed back to Active. The left-edge iOS back swipe remains
reserved for navigation.

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

Inventory item aliases help this flow recognize bill names that differ from the saved inventory
name. Add aliases such as brand names, abbreviations, or local ingredient names from the inventory
add/edit form.

Manual bill text entry remains available when an image is unclear.

## Review Stock History

Use stock history when the owner needs to understand why an item's quantity changed.

The history includes manual stock adjustments and manual stock usage for the selected inventory
item. This is useful before recipe-driven stock changes exist, and it becomes more important once
recipes start reducing inventory automatically.

## Import And Export Inventory CSV

Use Settings when inventory data needs to move into or out of CloudBake.

Inventory CSV export saves active inventory and stock batches with name, unit, current quantity,
minimum quantity, batch quantity, and expiry date.

Inventory CSV import creates new active inventory items or updates matching active items by name
and unit. When an imported row matches an existing item, the imported stock batches replace that
item's saved stock batches so the CSV can be used as a deliberate correction source. The owner
should review the CSV before import because there is no separate conflict review screen yet.

## Archive Inventory

Use archive when an item should not appear in the active inventory list anymore.

Examples:

1. the owner stopped using an ingredient,
2. a supplier item changed,
3. an old packaging size is no longer used.

CloudBake asks for confirmation before archiving. Archived items can be restored.

## Dashboard Workflow

Use the dashboard home screen to quickly orient the day, see work that needs attention, and move
into the main owner work areas.

Dashboard low inventory includes items below minimum quantity, items with expired remaining stock,
and items with remaining stock expiring within one month.

The home screen shows Today, Needs attention, and Quick actions. More holds secondary areas such as
Recipes, Customers, Designs, and Settings so Home does not become a long directory.

Second-level owner screens use the same CloudBake visual language: warm light background, compact
screen title, circular top actions in the header, card-based lists, and bottom quick navigation for
Home, Orders, Inventory, and More. These screens do not repeat the CloudBake logo; screens with
several actions, such as Inventory, can group those actions behind a compact `...` menu. Opening a
second-level screen from Home, or moving from one second-level screen to another, uses the native
iOS push animation. The left-edge back gesture returns to the previous screen without a visible
custom back button. CloudBake keeps a short recent section history, so tapping a recently visited
section behaves like going back to that screen instead of opening a duplicate copy.

Detail screens use a focused version of the same visual language: custom compact header, hero
summary card, titled card sections, visible row actions, and centered confirmation popups for
status/payment actions.

Order detail overview focuses on balance due and delivery address when the order is a delivery.
Notes and cake message content are shown as left-aligned block text below their labels so longer
owner notes and cake inscriptions stay readable.

Form screens keep native iOS data-entry controls while using the CloudBake background and pink
action tint, so create, edit, import, and correction flows feel connected to the rest of the app
without losing predictable keyboard, picker, and save/cancel behavior.

CloudBake currently uses light appearance only while the owner app design is hardened for dark mode.

## Settings Workflow

Use Settings for app-wide owner preferences and data tools.

The owner can choose the money display symbol from `$`, `₹`, `£`, `RM`, and `S$`. This changes local
display for order prices, payments, balances, and inventory amount. It does not convert stored
amounts or apply exchange rates.

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
20. use visible row actions to change status or record payment,
21. mark payment Paid or add a partial payment from order detail,
22. review the next relevant reminder in order detail,
23. add customer reference photos and final cake photos from the camera or photo library,
24. preview, caption, and delete saved order photos from order detail.

Active orders are grouped by due day, with orders inside each day ordered by delivery or pickup time
ascending. Completed and cancelled orders are kept out of active work and appear in a simple
Completed tab ordered by delivery or pickup date-time descending. Cancelled rows show a small red
indicator so they are not mistaken for fulfilled work.

iPad Orders layout is deferred while the owner app targets iPhone only. Order detail opens as a
focused sheet on supported iPhones.

The Orders screen no longer has a standalone Reminders Due section. Order detail shows the next
reminder for that cake. Completed and cancelled orders do not appear in due reminder calculations.
Confirmed, In Progress, and Ready orders also schedule local owner notifications for future
three-day, two-day, one-day, and due-time reminder times. If an active order has passed its due
time, CloudBake shows an Overdue pill on the order row and an update-status banner for the earliest
overdue order. Snooze, configurable reminder offsets, and calendar integration are future work.

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

From Designs detail, `Use for New Order` opens the normal add-order form with the selected image
already linked. The order remains an unsaved draft until Save is selected. Owner-made and internet
inspiration items retain their saved-design relationship; customer references retain a separate
originating order-photo relationship so their provenance is not changed.

Design and customer-reference detail photos support pinch zoom. Labelled zoom controls provide the
same inspection workflow without requiring a pinch gesture. Swipe horizontally to move to the next
or previous item in the current filtered source collection; vertical swipes continue scrolling the
detail screen.

The add action beside My Designs imports completed owner work directly from the iPhone Photos
library. A name is required; notes and comma-separated tags are optional. CloudBake stores the
Photos asset reference and metadata only, and the design remains private by default.

Order detail also includes a Photos section for order-specific images. Customer References are for
images the customer shares before preparation, while Final Cake Photos are for what the owner made
and delivered. Each group shows compact camera and photo-library icons beside the group title. The
owner can add either kind from the camera or photo library, open saved photos in a full-screen
preview, edit captions, save final cake photos as reusable designs, and delete mistaken photo rows.
Saving a final photo as a design creates a linked cake design record using the photo's local
reference path.

When a Confirmed order with an unused linked recipe is marked Ready or Completed from order detail,
the app asks for confirmation and then deducts the recipe's inventory-backed ingredient rows. When
the same status transition is saved through edit order, the app uses the same one-time deduction
rule.
The order form includes a Recipe Multiplier for scaling the linked recipe up or down before usage.
Quantities are converted into each inventory item's unit when compatible, then multiplied by the
order recipe multiplier. Order form and order detail can also add order-specific extra ingredients
under Recipe Information for customer-specific changes that should not update the saved recipe.
Extra ingredients show as a simple quantity list, can be deleted before recipe usage is recorded,
and are deducted with the linked recipe as exact order quantities. Stock batches are consumed
oldest-expiry-first, and the usage can be recorded only once for the order to prevent accidental
double deduction. Partial recipe usage, multi-recipe orders, inventory reservation, and
serving/yield modeling remain future work.

Order detail includes a Checklist section for owner preparation tasks such as crumb coat, topper
pickup, box ready, or final photo. The owner can add checklist items, edit item titles, and tap any
checklist row to mark it complete or incomplete. Checklist items stay in entry order and can be
deleted from order detail. Checklist reordering, templates, and checklist-driven status changes are
future work.

Order add/edit includes a Pricing And Payment section for the owner-entered quoted price, deposit
paid, and payment notes. Order detail shows payment status, quoted price, deposit paid, and derived
balance due. From order detail, the owner can mark the order Paid or add a partial payment without
opening full edit. Marking Paid sets the paid amount to the quoted price and makes balance due zero.
Adding a partial payment asks for the newly received amount and adds it to the existing paid amount.

Order rows also expose visible action chips for quick status changes and payment recording. These
quick actions use centered popups and ask for confirmation before saving. Pricing suggestions,
recipe-cost calculation, discounts, refunds, and online payment processing remain future work.

Future order slices should add reminder snooze, configurable reminders, partial recipe usage,
multi-recipe orders, inventory reservation, checklist reordering/templates, pricing calculation,
and richer order photo/design library workflows.

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

Customer detail supports deletion after confirmation. Deleting a customer clears optional order
record links but keeps each order's customer name snapshot, so historical orders remain readable.

The app warns before saving when a new customer looks like a duplicate. Contacts import can prefill
contact details, but CloudBake-specific preferences and allergy notes remain owner-entered.

Orders can link to customer records today. Linked order detail surfaces saved customer preferences
and allergy details for owner review. Customer detail also shows linked orders in due-date order so
the owner can review a customer's cake history from the customer record. Order add/edit uses a
searchable customer selection flow so saved customers remain usable as the list grows. If the
customer is missing while creating an order, the owner can create a new customer from the selection
screen by importing from Contacts or entering manually, then immediately link that saved customer to
the order draft.

iPad Customers layout is deferred while the owner app targets iPhone only. Customer detail opens as
a focused sheet on supported iPhones.

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
