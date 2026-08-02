# Slice RFC-0131: Structured Order Requirements And Summary

## Status

Implemented.

## Context

Cake requirements currently depend mainly on a cake name and free-form notes. That remains useful,
but it makes quoting, repeating a familiar cake, and confirming the full request harder than it
needs to be. The owner needs structured cake details without turning the order form into a long,
mandatory questionnaire.

## Scope

1. Add these optional cake-requirement fields to an order:
   - occasion,
   - servings,
   - size,
   - weight in kilograms,
   - shape,
   - tiers,
   - sponge flavour,
   - filling,
   - frosting,
   - colour palette,
   - theme,
   - topper requirements,
   - candles and accessories,
   - packaging.
2. Keep Cake Name as the only required cake field. Every new structured field may remain empty.
3. Present the fields in small related groups so the form remains calm and does not show one long
   undifferentiated list.
4. Use compact initial choices:
   - occasion: Birthday, Wedding, Anniversary, Baby Shower, Celebration, Other;
   - size: 4 in, 6 in, 8 in, 10 in, 12 in, Other;
   - shape: Circle, Square, Oval, Other;
   - tiers: 1, 2, 3, Other;
   - sponge flavour: Vanilla, Chocolate, Other;
   - filling: Buttercream, Chocolate Ganache, Fruit, Other;
   - frosting: Buttercream, Whipped Cream, Ganache, Fondant, Other;
   - packaging: Standard Box, Tall Box, Window Box, Other.
5. Occasion, size, shape, tiers, sponge flavour, filling, and frosting begin empty. Topper and
   candles/accessories default to None. Packaging defaults to Standard Box.
6. Choosing Other reveals a text field. A non-empty custom value becomes a reusable choice after a
   successful order or template save. Reusable choices are case-insensitively unique and remain
   owner-private.
7. Colour palette and theme remain concise free-form fields whose previously saved values may be
   offered as reusable suggestions. They are not restricted to a fixed catalogue.
8. Servings accepts a positive whole number. Weight accepts a positive decimal number in kilograms.
9. Use an average of 14 servings per kilogram:
   - servings can suggest weight, rounded to at most one decimal place;
   - weight can suggest servings, rounded to the nearest whole serving.
10. A suggestion never overwrites an owner-entered value. It remains a separate action until the
    owner accepts it, and no suggestion is shown when both fields already contain values.
11. Generate a short plain-English summary in a stable order: occasion, capacity, physical form,
    sponge/filling/frosting, visual direction, topper/accessories, and packaging.
12. Omit empty values and the literal None from the summary. Do not add explanatory notes intended
    for non-professionals.
13. Persist the summary inputs as structured fields; derive the summary rather than storing a second
    editable copy.
14. Order detail shows the generated summary and the structured values that are present.
15. Duplicate Order, customer-history reuse, and reusable order templates carry every structured
    cake requirement. They continue to exclude customer/commercial/history fields according to
    slices 0128–0130.
16. Existing orders and templates migrate with empty structured requirements and retain their
    current cake name and notes unchanged.
17. Backup and restore include the structured requirements and reusable custom choices.

## Example Summary

For Birthday, 28 servings, 2 kg, Circle, 2 tiers, Chocolate sponge, Chocolate Ganache filling,
Fondant frosting, a pink-and-gold palette, floral theme, name topper, candles, and Standard Box:

> Birthday cake for 28 servings (2 kg), circle, 2 tiers, with chocolate sponge, chocolate ganache
> filling, and fondant frosting; pink and gold with a floral theme; name topper and candles; packed
> in a standard box.

## Validation

1. Unit tests cover option normalization, custom-choice uniqueness, servings/weight suggestions,
   no-overwrite behavior, validation, and summary omission/order rules.
2. Persistence tests cover migration defaults, full order round trips, template round trips, custom
   choices, and backup/restore representation.
3. View-model tests cover fresh, edit, duplicate, customer-history, and template-application drafts.
4. A focused acceptance journey creates an order with structured requirements, verifies its summary,
   and reopens it for editing.

## Out Of Scope

1. Automatic price calculation from size, servings, tiers, or decoration complexity.
2. Enforcing a relationship between dimensions, shape, tiers, weight, and servings.
3. A bundled day-one catalogue of reusable order templates; that follows as a separate slice after
   the structured template schema is available.
4. Customer-facing order configuration or publication.

## Documentation Decision

This changes durable order creation, detail, duplication, and template behavior. Update the Orders
RFC, Owner Workflows, and Current App Capabilities in the implementation PR. The canonical CloudBake
screen RFC and slice map require a companion foundation documentation change.
