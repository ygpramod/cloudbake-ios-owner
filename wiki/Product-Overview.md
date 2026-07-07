# Product Overview

CloudBake is an owner-first app for running a handmade cake business.

The first version is for the bakery owner, not customers. It helps the owner keep operational truth
in one place: inventory, recipes, cake designs, customer preferences, orders, reminders, and pricing.

## Product Direction

CloudBake starts as a private owner tool.

Current direction:

1. work offline on iPhone and iPad,
2. store data on the device first,
3. support handmade cake workflows instead of generic restaurant inventory workflows,
4. support recipe-driven inventory reduction when Confirmed orders become Ready or Completed,
5. grow toward order calendar reminders,
6. grow toward cake design and customer preference memory,
7. add iCloud or backend sync only when the owner workflow needs it,
8. add customer-facing features later.

## Owner App First

The owner app should make daily bakery work easier:

1. know what ingredients are available,
2. know what is running low,
3. remember recipes and cake design references,
4. plan orders and delivery dates,
5. track customer likes, dislikes, and allergies,
6. price handmade cakes with owner-controlled judgment,
7. keep private business details private.

## Handmade Cake Assumptions

CloudBake assumes cakes are handmade and custom.

That means:

1. pricing is not only formula-based,
2. design work, complexity, and owner judgment matter,
3. customer preferences matter,
4. ingredients may be tracked in practical kitchen units,
5. recipes may begin as handwritten or book-based notes,
6. past cake photos and designs become useful business memory.

## Future Customer Experience

The future customer-facing experience may allow customers to:

1. browse cake designs,
2. request minor design improvements,
3. explore flavors,
4. provide preferences and allergy information,
5. start an order request.

Private owner data, internal costs, supplier notes, recipes, and operational reminders must not leak
into any customer-facing experience.

The app now has a domain-only consumer order preview model that defines the first safe projection
boundary for future customer-facing order status and cake preview surfaces. It is not a public UI or
sync feature yet.

The app also has a domain-only consumer customer profile model that defines the first safe
projection boundary for future authenticated customer profile surfaces. It is not a customer account,
public UI, or sync feature yet.
