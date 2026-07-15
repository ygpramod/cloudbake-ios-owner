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

Use the `+` beside the Ingredients heading when the owner wants to manually define the stock needed
by a recipe. Tap an ingredient row to edit it, or use the visible delete action for a mistaken row.

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

Use the `+` beside the Items heading when a new ingredient or supply needs to be tracked.

Before adding, the app warns when an existing item has the same or similar name. This helps avoid
duplicates like multiple cake flour rows.

Inventory type can be Standard or Perishable. Standard is the default. Perishable is for short-life
ingredients such as fruit.

When starting quantity is entered, expiry is selected by default but can be turned off before
saving. Standard inventory defaults expiry to one month from the add date. Perishable inventory
defaults the expiry date to four days from the add date.

Enter Default Expiry (Days) when this item should use a different shelf life. It must be a positive
whole number. CloudBake uses it for future initial stock, stock adjustments, and matched
purchase-bill drafts; each batch expiry can still be changed or removed before saving.

## View Inventory

Tap an inventory row to view the item.

The active inventory list prioritizes items that need attention. Items with expired stock appear
first, then items below minimum quantity, then items expiring soon, followed by normal stock.

Each active card keeps the summary lean with the item name and current quantity. Use the centered
`+` and `−` pills to adjust or use stock. Swipe right to reveal History. Swipe left to reveal
Archive and Delete.

Use inventory search when the list grows. Search matches inventory item names and stored units while
preserving the same attention-first ordering inside the search results.

The view mode shows name, type, unit, current quantity, minimum quantity, and an expiry table. The
expiry table lists each remaining stock batch by quantity and expiry date.

The detail view exposes a direct edit action and visible action chips for history, use stock, and
adjust stock, so the owner does not need to return to the list and swipe for common item work.

Tap a batch in the expiry table when that batch's quantity or expiry date needs correction. Use the
visible delete action when a mistaken batch should be deleted.

## Edit Inventory

Use edit inventory when the item name, minimum quantity, or default expiry days needs correction.

Editing is reached from the inventory detail view.

Current quantity should be changed through stock adjustment or stock consumption. Unit and existing
batch expiry dates are not edited from item edit mode. Changing default expiry days affects future
stock only.

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
expiry dates differ. An item-level default expiry overrides the type default; otherwise Perishable
inventory uses four days and Standard inventory uses one month from the adjustment date.

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

## Add Inventory By Voice

Open the Inventory header actions and choose Add Inventory by Voice. Start listening and speak
items as `name quantity unit`, or type directly into the editable transcript. CloudBake uses only
on-device recognition in the current iPhone language. It never uploads the audio or transcript.
When you pause before speaking the next item, CloudBake keeps the earlier text and places the next
utterance on a new line. If you edit the transcript while listening, later speech continues from
the edited text instead of restoring the recognizer's earlier wording.

Choose Create Drafts, review the parsed rows, and decide how every unknown item should be saved.
Map an unknown name to searchable, unit-compatible inventory to add stock and preserve the spoken
name as an alias, or create a new item. Mapped drafts retain the saved item's minimum quantity;
minimum quantity is requested only when creating new inventory. Only one exact saved name or alias
matches automatically;
partial and ambiguous matches require a decision. Editing a draft name rechecks that destination.
Saving is disabled until the transcript produces drafts and every unknown item has a destination,
then commits the complete voice import atomically.

## Review Stock History

Use stock history when the owner needs to understand why an item's quantity changed.

The history includes manual stock adjustments and manual stock usage for the selected inventory
item. This is useful before recipe-driven stock changes exist, and it becomes more important once
recipes start reducing inventory automatically.

## Import And Export Inventory CSV

Use Settings when inventory data needs to move into or out of CloudBake.

Inventory CSV export saves active inventory and stock batches with name, aliases, inventory type,
default expiry days, unit, current quantity, minimum quantity, batch quantity, amount, and expiry
date.

Inventory CSV import creates new active inventory items or updates matching active items by name
and unit. When an imported row matches an existing item, the imported stock batches replace that
item's aliases, inventory type, default expiry days, and saved stock batches so the CSV can be used
as a deliberate correction source. Import requires the `aliases`, `type`, and
`default_expiry_days` columns. The owner should review the CSV before import because there is no
separate conflict review screen yet.

## Import And Export Recipe CSV

Recipe CSV export uses the columns `name`, `recipe`, and `ingredients`. The recipe field contains
notes or instructions. Ingredients use `name:quantity:unit` and are separated with `|`, for example
`Cake Flour:250:g | Sugar:200:g`.

Every export includes a row whose name starts with `# Example`; CloudBake ignores that row during
import. Imported ingredient names must match exactly one active inventory item name or alias.
Malformed, unmatched, ambiguous, or duplicate recipe rows are rejected instead of being partially
interpreted.

## Archive Inventory

Use archive when an item should not appear in the active inventory list anymore.

Examples:

1. the owner stopped using an ingredient,
2. a supplier item changed,
3. an old packaging size is no longer used.

CloudBake asks for confirmation before archiving. Archived items can be restored.

Unused inventory can also be deleted permanently from an active card or Archived Inventory.
CloudBake blocks deletion when the item is linked to stock history, a recipe, or an order, and asks
the owner to archive it instead so operational records remain intact.

## Dashboard Workflow

Use the dashboard home screen to quickly orient the day, see work that needs attention, and move
into the main owner work areas.

Dashboard low inventory includes items below minimum quantity, items with expired remaining stock,
and items with remaining stock expiring within one month.

The home screen shows Today, Needs attention, and Quick actions. More holds secondary areas such as
Recipes, Customers, Designs, and Settings so Home does not become a long directory. Upcoming Orders
includes active orders due from today through the end of the thirtieth day; later orders remain in
Orders and Calendar.

Second-level owner screens use the same CloudBake visual language: warm light background, compact
screen title, circular top actions in the header, card-based lists, and bottom quick navigation for
Home, Orders, Inventory, and More. These screens do not repeat the CloudBake logo; screens with
several actions, such as Inventory, can group those actions behind a compact `...` menu. Opening a
second-level screen from Home, or moving from one second-level screen to another, uses the native
iOS push animation. The left-edge back gesture returns to the previous screen without a visible
custom back button. CloudBake keeps a short recent section history, so tapping a recently visited
section behaves like going back to that screen instead of opening a duplicate copy.

Detail screens use a focused version of the same visual language: custom compact header, hero
summary card, titled card sections, visible row actions, native menus for compact choices, and
centered confirmation popups for protected mutations and input.

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

Under Appearance, the owner can choose a photo to replace the CloudBake logo shown in the dashboard
header. CloudBake keeps an app-managed copy so the selection remains available after relaunch. The
owner can restore the bundled default logo at any time. This setting does not change the iPhone Home
Screen app icon.

Backup and Data Management are collapsed by default. Expand Backup and choose **Create Full
Backup** to prepare one validated `.cloudbakebackup` package, then use the system Files picker to
save it to a safe location such as iCloud Drive. The package contains the complete local database,
app-managed photos, lightweight recovery copies of linked iPhone Photos images, and the custom logo.
It is private business data and should not be shared casually.

CloudBake records the last successful save and enables a weekly backup reminder by default. The
owner can disable that reminder independently. Cancelling the Files picker or an export failure does
not update the last-backup date. Direct import of a `.cloudbakebackup` file is not currently
available, so retain the package and use iPhone or encrypted Finder backup as an additional
device-level recovery option.

CloudBake provides one best-effort automatic disaster-recovery backup to
the owner's private CloudKit database each eligible night. Automatic transfer is Wi-Fi-only, can be
deferred by iCloud account, power, thermal, or storage conditions, and catches up asynchronously
after a missed run. Before the first publication to the current iCloud account, CloudBake asks the
owner to confirm that account. A changed Apple account requires fresh confirmation, and unavailable
or changed accounts never alter local bakery data. iOS decides the actual execution time.

Expand **Backup** to see whether cloud backup is enabled, iCloud availability, the latest safe
status and guidance, the last successful backup time, and the estimated transfer size. Cloud backup
starts enabled. Turning it off stops future automatic and manual cloud publication but retains the
latest successful recovery snapshot. Backup notifications are a separate preference; turning them
off does not turn off backup or hide Settings status.

Choose **Back Up Now** for a fresh manual cloud snapshot. CloudBake creates and publishes a new
snapshot even when no app data has changed since the previous backup. Wi-Fi proceeds without a
data-use prompt. On cellular, CloudBake displays the estimated transfer size and publishes only
after explicit approval. That approval applies to one backup attempt; a later cellular backup asks
again. Status and notifications use safe operational wording and never include customer, recipe,
cost, or photo content.

Expand **Data Management** and choose **Delete Cloud Backup** to permanently remove CloudBake's
complete recovery backup from the current private iCloud account. A destructive confirmation is
required. Successful deletion removes current and abandoned backup generations, leaves all local
data and photos unchanged, and turns cloud backup off until the owner explicitly enables it again.
If deletion cannot be verified, CloudBake reports that uncertainty and keeps backup off so an
automatic run cannot silently recreate the backup. The owner can retry deletion safely.
Turning backup off by itself is different: it retains the latest cloud snapshot.

Expand **Data Management** and choose **Restore from Cloud Backup** to inspect the latest recovery
snapshot. CloudBake shows its date, size, photo count, integrity, and compatibility before any
download. A new empty installation offers **Restore Backup** or **Start Fresh** and never restores
automatically. Replacing an installation that already contains owner data requires a separate
destructive confirmation and a local rollback snapshot. A selected custom logo also counts as
owner data even when no business records exist. Cellular transfer also requires approval of the
displayed size.

CloudBake reinspects the complete displayed snapshot metadata immediately before download. If its
generation, size, photo count, integrity, or app compatibility changed, the restore stops so the
owner can inspect and approve the current snapshot instead. Storage exhaustion during staging or
database migration is reported as a storage problem and leaves the active installation unchanged.

CloudBake downloads and validates the complete database and app-managed photos in staging, migrates
compatible older data, and activates it only after verification. If photos are missing or damaged,
choose **Ignore Broken Photos** to retain their references or **Remove Photo References** to clean
them from the restored database. Network, iCloud, cancellation, and local storage errors do not
mislabel photos as broken. Activation failure returns to the pre-restore local snapshot, and the
next launch completes rollback if the app was interrupted. After success, CloudBake reloads the
restored data, refreshes local reminders, and resumes backup catch-up. A backup from a newer
incompatible app version is not restored; CloudBake asks the owner to update. Permanent cloud
deletion remains unavailable until its account-lifecycle safety slice ships. If CloudBake cannot
guarantee rollback, it blocks all app interaction and asks the owner to close and reopen the app so
startup recovery can finish before any further changes. Automatic and manual cloud backup also
remain blocked, preventing unrecovered state from replacing the last safe cloud snapshot.

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
17. mark an order Ready or Completed from detail or edit order and deduct linked recipe
    ingredients from inventory with unit conversion,
18. add, complete, and delete simple preparation checklist items from order detail,
19. review completed and cancelled orders in a separate Completed tab,
20. use visible row actions with native iOS menus to change status or record payment,
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
existing design reference, clear the link, and review the linked design name, notes, and compact
photo thumbnail from order detail. Selecting the thumbnail opens the linked photo in a centered,
full-screen detail view.

From Designs detail, `Use for New Order` opens the normal add-order form with the selected image
already linked. The order remains an unsaved draft until Save is selected. Owner-made items retain
their saved-design relationship; customer references retain a separate originating order-photo
relationship so their provenance is not changed.

Design and customer-reference detail photos support pinch zoom. Labelled zoom controls provide the
same inspection workflow without requiring a pinch gesture. Swipe horizontally to move to the next
or previous item in the current filtered source collection; vertical swipes continue scrolling the
detail screen.

The add action beside My Designs imports completed owner work directly from the iPhone Photos
library. A name is required; notes and comma-separated tags are optional. CloudBake stores the
Photos asset reference and metadata only, and the design remains private by default.

The order form opens a photo-first Designs grid for linking a saved owner-made design or Customer
Reference. Search works across names, notes, customer/order context, and tags, and the ribbon shows
the ten most-used tags. Internet Inspiration is not offered for new links; existing historical
links retain their label while an order is edited.

Order detail also includes a Photos section for order-specific images. Customer References are for
images the customer shares before preparation, while Final Cake Photos are for what the owner made
and delivered. Each group shows compact camera and photo-library icons beside the group title. The
owner can add either kind from the camera or photo library, open saved photos in a full-screen
preview, edit captions, save final cake photos as reusable designs, and delete mistaken photo rows.
Saving a final photo as a design creates a linked cake design record using the photo's local
reference path.

When an order with an unused linked recipe is marked Ready or Completed from order detail,
the app asks for confirmation and then deducts the recipe's inventory-backed ingredient rows. When
the same status transition is saved through edit order, the app uses the same one-time deduction
rule. Draft and In Progress orders cannot bypass deduction by moving directly to Ready or Completed.
If validation fails, CloudBake immediately explains the missing recipe data, incompatible unit, or
insufficient stock and keeps the previous status.
The order form includes a Recipe Multiplier for scaling the linked recipe up or down before usage.
Quantities are converted into each inventory item's unit when compatible, then multiplied by the
order recipe multiplier. Order form and order detail can also add order-specific extra ingredients
under Recipe Information for customer-specific changes that should not update the saved recipe.
Extra ingredients show as a simple quantity list, can be deleted before recipe usage is recorded,
and are deducted with the linked recipe as exact order quantities. Stock batches are consumed
oldest-expiry-first. Before deduction, CloudBake compares usable non-expired inventory with the
combined scaled recipe and extra-ingredient demand from every active order. A shortage appears on
each contributing order and in Dashboard and Reminders. This projection does not reserve or deduct
stock and disappears after usage is recorded or the order is Completed or Cancelled.

The usage can be recorded only once for the order to prevent accidental double deduction. Partial
recipe usage, multi-recipe orders, inventory reservation, and
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

When a linked recipe has inventory-backed ingredients, the order form shows Estimated Ingredient
Cost beside the quoted-price input so the owner can use it while preparing a quote. The estimate
updates when the recipe, scale, or extra ingredients change. It includes every priced portion and
displays a warning when a required batch has no purchase amount. Order detail shows the same estimate;
tap that row to expand the per-ingredient breakdown. After inventory is deducted, the row becomes
Actual Ingredient Cost and uses the cost of the exact usable batches consumed. Expired stock never
contributes cost, and ingredient cost does not change the quoted price automatically.

CloudBake keeps separately entered priced purchases as separate batches, even when their expiry date
and amount match. This preserves the purchase quantity and unit cost used by order costing.

Order rows also expose visible action chips with compact native menus for quick status changes and
payment recording. Ordinary status and Mark Paid choices apply directly. Partial-payment input and
status transitions that deduct recipe inventory retain explicit centered confirmation. Pricing
suggestions,
discounts, refunds, and online payment processing remain future work.

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
