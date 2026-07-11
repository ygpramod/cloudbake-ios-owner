# Current App Capabilities

This page lists what the app currently supports. It should stay factual and product-focused.

## Available Now

The app currently supports:

1. native iPhone app shell,
2. visual dashboard home screen with Today, Needs attention, and Quick actions sections, clickable
   upcoming order and attention rows, and bottom quick navigation for Home, Orders, Inventory, and
   More,
3. inventory navigation,
4. local SQLite persistence,
5. inventory item creation,
6. current quantity and minimum quantity tracking,
7. low-inventory detection,
8. duplicate inventory warning,
9. inventory item detail view,
10. inventory item editing for name and minimum quantity,
11. inventory archive confirmation,
12. archived inventory restore,
13. stock adjustment,
14. stock consumption,
15. stock history for active inventory items,
16. inventory item type for Standard and Perishable stock behavior,
17. optional expiry dates when adding inventory and adjusting stock,
18. four-day default expiry for Perishable stock,
19. stock batches with expiry dates,
20. expiry table for remaining stock batches,
21. expiry-driven low inventory alerts,
22. perishable low-inventory alert suppression unless an active order recipe or extra ingredient
    needs the item,
23. one-month upcoming expiry alerts,
24. stock batch quantity, amount, and expiry editing,
25. stock batch combining when added stock has the same expiry date and amount,
26. stock batch deletion from inventory detail,
27. oldest-expiry-first stock consumption,
28. compatible unit conversion for stock adjustment and stock usage,
29. searchable active inventory list with attention-first ordering inside search results,
30. inventory detail pencil edit and visible action chips for history, use, and adjust,
31. inventory aliases for purchase bill names, brand names, abbreviations, and local ingredient
    names,
32. bundled baking catalog config for future purchase bill filtering,
33. purchase bill text parsing into draft inventory candidates,
34. local Apple Vision OCR service for purchase bill text recognition,
35. purchase bill draft review and save into inventory,
36. purchase bill camera capture into editable inventory drafts,
37. purchase bill photo retake and selected-photo preview,
38. purchase bill photo library import,
39. duplicate matching for purchase bill draft save,
40. local expiry reminder notifications for stock expiring within one month,
41. owner-selected currency setting for money display,
42. recipe list,
43. recipe creation with name and owner notes,
44. recipe paper/book photo import into editable drafts,
45. local Apple Vision OCR service for recipe text recognition,
46. recipe detail view,
47. manually linked recipe ingredient rows with quantity, unit, and note,
48. recipe ingredient editing and deletion,
49. structured recipe import drafts with parsed ingredient rows,
50. simple inventory matching for imported recipe ingredients,
51. recipe name and notes editing from recipe detail,
52. customer list,
53. manual customer creation,
54. customer detail view,
55. customer duplicate warning,
56. customer important dates,
57. customer editing from detail,
58. Contacts import into editable customer drafts,
59. customer detail order history for linked orders,
60. customer deletion from detail after confirmation,
61. deferred iPad customer layout,
62. orders list,
63. order creation,
64. order detail view,
65. optional customer record link from orders,
66. searchable customer record selection from order add/edit,
67. new customer creation from order customer selection,
68. order due date/time, status, fulfillment type, delivery address, cake notes, and cake message,
69. order editing from detail,
70. manual order status changes,
71. orders Active tab grouped by due day with delivery or pickup time ordering,
72. linked customer allergies, dietary restrictions, preferences, and notes in order detail,
73. in-app order reminder planning for three, two, and one day before due date with one next
    relevant reminder shown in the UI,
74. optional saved recipe link from order add/edit,
75. linked recipe name in order detail,
76. status changes from order detail without opening the full edit form,
77. owner-confirmed linked recipe usage when a Confirmed order is marked Ready or Completed,
78. recipe-driven inventory deduction with unit conversion, recipe scaling, and
    oldest-expiry-first batch usage,
79. order-specific extra ingredients from order form or linked recipe detail, with inventory-backed
    deduction during recipe usage,
80. order detail checklist item add, edit, complete/incomplete toggle, entry-order display, and
    deletion,
81. deferred iPad order layout,
82. optional saved cake design link from order add/edit,
83. simple Completed orders tab for completed and cancelled orders ordered by delivery or pickup
    date-time descending,
84. linked design name, notes, and photo reference in order detail,
85. completed order tab that keeps completed and cancelled orders out of active order views, with
    cancelled rows visibly marked,
86. owner-entered order quoted price, deposit paid, derived balance due, payment status, and payment
    notes,
87. visible order row actions for quick status changes and payment recording,
88. order detail payment status actions for marking Paid or adding a partial payment,
89. scheduled local owner notifications for Confirmed, In Progress, and Ready order reminders,
90. due-time order notifications that route back to the matching order,
91. overdue order row pills and an in-app update-status banner for the earliest overdue order,
92. local order photo metadata and app-owned local photo file storage,
93. order detail photo groups for customer reference photos and final cake photos,
94. photo library import for order reference and final cake photos,
95. camera capture for order reference and final cake photos,
96. full-screen preview for saved order photos,
97. caption editing for saved order photos,
98. promotion of final cake photos into linked saved cake designs,
99. saved order photo deletion from order detail,
100. Settings inventory CSV import and export for active inventory and stock batches,
101. Reminders screen with payment due WhatsApp/Mark as Paid actions, today's orders, low inventory
    sections, and detail routing,
102. shared CloudBake visual styling for second-level Orders, Inventory, Recipes, Customers, Designs,
    and Settings screens, with compact title headers and grouped Inventory header actions,
103. native iOS push navigation with short recent-page history and left-edge swipe back to the
    previous screen,
104. shared CloudBake visual styling for order, inventory, recipe, and customer detail screens,
105. shared CloudBake visual styling for owner-facing create, edit, import, and correction forms,
106. centered CloudBake confirmation popups for order, customer, and inventory actions,
107. unit, integration, and feature-sharded acceptance test lanes.
108. persisted cake-design provenance for owner-made, customer-reference, and internet-inspiration
    records, including optional originating order and order-photo relationships.
109. an owner-made My Designs photo gallery and design detail view backed by referenced Photos
    assets, with explicit handling when an asset is unavailable.
110. Photos-owned design images: CloudBake saves newly promoted designs to the iPhone Photos
    library and stores only the returned local asset identifier, while retaining read-only legacy
    reference compatibility.

## Partially Prepared

The app has domain foundations or partial workflows for:

1. recipe components and ingredients,
2. cake designs,
3. customer-safe order preview projection for future consumer-facing surfaces,
4. customer-safe profile projection for future consumer-facing surfaces,
5. order reminder snooze and configurable reminder offsets,
6. inventory transactions,
7. purchase bill filtering by baking catalog,
8. purchase bill draft inventory parsing,
9. purchase bill text recognition through Apple Vision,
10. purchase bill draft review flow,
11. purchase bill camera import flow,
12. purchase bill duplicate matching,
13. recipe ingredient quantity extraction.

These are not all owner-facing workflows yet.

## Future Product Areas

Planned product areas include:

1. stronger OCR cleanup and page correction for scanned recipes,
2. optional LLM-assisted recipe interpretation,
3. partial recipe usage,
4. multi-recipe orders and inventory reservation,
5. order checklist reordering and templates,
6. reminder snooze and configurable reminder offsets,
7. pricing calculator,
8. customer-facing cake browsing,
9. sync through iCloud or backend when needed.

## Source References

Detailed implementation truth lives in:

1. `README.md`,
2. `docs/engineering-guardrails.md`,
3. `docs/adr/`,
4. `docs/rfc/slices/`,
5. app and test source files.
