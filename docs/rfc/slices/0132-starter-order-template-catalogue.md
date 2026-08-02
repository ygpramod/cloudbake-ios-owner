# Slice RFC-0132: Starter Order Template Catalogue

## Status

Accepted for implementation.

## Context

Reusable order templates are useful only after the owner has configured and saved combinations.
CloudBake should demonstrate that workflow immediately with a small professional starter catalogue,
without coupling templates to customer, pricing, recipe, inventory, or design data that does not
exist on a new installation.

## Scope

1. Seed these six starter templates once:
   - Classic Birthday Cake,
   - Chocolate Birthday Cake,
   - Anniversary Cake,
   - Baby Shower Cake,
   - Floral Celebration Cake,
   - Two-Tier Wedding Cake.
2. Use only reusable order-template fields: cake name, structured cake requirements, pickup
   fulfilment, and the default reminder snapshot.
3. Do not seed customer, delivery address, due date, status, quoted price, payment, recipe,
   inventory ingredient, design, photo, checklist, or history data.
4. Keep starter requirements concise and editable. Empty fields remain empty rather than inventing
   servings, weight, size, colour, topper, or accessory decisions the owner has not made.
5. Seed through one database migration so existing installations receive the catalogue on upgrade
   and new installations receive it on first launch.
6. Starter templates become ordinary owner templates after seeding. The owner may apply, rename, or
   delete them using the existing template library.
7. A renamed or deleted starter template must not be recreated on later launches or migrations.
8. Use deterministic private identifiers and conflict-safe insertion so migration replay cannot
   duplicate a template.
9. Templates are included automatically in the existing full database backup and restore.

## Starter Contents

| Template | Occasion | Shape/Tiers | Sponge | Filling/Frosting | Theme | Packaging |
| --- | --- | --- | --- | --- | --- | --- |
| Classic Birthday Cake | Birthday | Circle / 1 | Vanilla | Buttercream / Buttercream | — | Standard Box |
| Chocolate Birthday Cake | Birthday | Circle / 1 | Chocolate | Chocolate Ganache / Ganache | — | Standard Box |
| Anniversary Cake | Anniversary | Circle / 1 | Vanilla | Fruit / Buttercream | Elegant | Standard Box |
| Baby Shower Cake | Baby Shower | Circle / 1 | Vanilla | Buttercream / Buttercream | Baby Shower | Standard Box |
| Floral Celebration Cake | Celebration | Circle / 1 | Vanilla | Fruit / Buttercream | Floral | Tall Box |
| Two-Tier Wedding Cake | Wedding | Circle / 2 | Vanilla | Fruit / Buttercream | Elegant | Tall Box |

All starters default topper and candles/accessories to None. Values omitted from this table remain
empty.

## Validation

1. Migration tests prove all six templates are inserted once with the intended structured values.
2. A migration replay does not duplicate templates.
3. Deleting or renaming a starter remains durable after repository reload.
4. A focused acceptance test opens Add Order, applies one starter, and verifies the structured
   requirement summary while customer and commercial inputs remain empty.

## Out Of Scope

1. Region-specific cake sizes, weights, servings, or pricing.
2. Seeded recipes, ingredients, designs, checklists, delivery details, or customer records.
3. A protected or separately branded built-in-template type.
4. Remote catalogue updates.

## Documentation Decision

This changes first-run and upgraded template-library behavior. Update the Orders RFC, Owner
Workflows, and Current App Capabilities in the implementation PR. Add slice 0132 to the canonical
CloudBake Orders screen RFC and slice map in a companion foundation documentation change.
