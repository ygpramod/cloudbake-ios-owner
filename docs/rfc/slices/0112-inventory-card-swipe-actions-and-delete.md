# Slice RFC-0112: Inventory Card Swipe Actions And Guarded Delete

## Status

Implemented.

## Goal

Keep active inventory cards lean while preserving quick access to history, archive, and deletion.

## Scope

1. Keep only name and current quantity in the active inventory summary row.
2. Remove inline Adjust and Use actions from active cards; keep both actions in inventory detail.
3. Reveal History by swiping an active card to the right.
4. Reveal Archive and Delete by swiping an active card to the left.
5. Confirm archive and permanent deletion before changing data.
6. Offer permanent deletion from Archived Inventory as well.
7. Delete only inventory items with no stock batches, transaction history, recipe ingredients,
   order extra ingredients, or recorded order ingredient costs.
8. When an item is in use, preserve it and direct the owner to archive it instead.
9. Keep cards centered at rest, with swipe actions hidden until the owner swipes.
10. Use neutral swipe-action surfaces and carry action color on the icons only.
11. Match active card typography, compact row icon, spacing, and density to Home screen rows.
12. Keep revealed action icons prominent and snap a return swipe to the closed card before the
    opposite action side can be revealed.
13. Let the owner swipe horizontally on the inventory filter ribbon to move between adjacent
    filters without intercepting the card-level History, Archive, and Delete swipes.

## Out Of Scope

1. Cascading deletion of recipes, orders, costs, or inventory history.
2. Removing minimum quantity or expiry from inventory detail and edit screens.
3. Changing stock adjustment, stock usage, or archive persistence semantics.

## Acceptance

1. Active cards do not show minimum quantity or expiry.
2. Active cards do not show Adjust or Use actions.
3. A right swipe reveals History and opens the existing history screen.
4. A left swipe reveals Archive and Delete.
5. Archive remains reversible from Archived Inventory.
6. Archived Inventory offers Delete with confirmation.
7. An unused item is permanently removed.
8. A referenced item is not deleted and the owner sees archive guidance.
9. History is not visible or hittable before a right swipe.
10. History, Archive, and Delete use colorful icons without colored action backgrounds.
11. Active cards use the same compact row hierarchy as Home cards.
12. A swipe returning from either action side closes the card without overshooting to the other side.
13. Filter-ribbon swipes move between All, Low stock, and Expiring soon in order.

## Validation

1. View-model tests cover successful and dependency-blocked deletion.
2. GRDB integration tests prove unused deletion and history protection.
3. Inventory acceptance tests cover both swipe directions and the existing archive/restore and
   stock-history journeys.
