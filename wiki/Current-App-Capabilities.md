# Current App Capabilities

This page lists what the app currently supports. It should stay factual and product-focused.

## Available Now

The app currently supports:

1. native iPhone and iPad app shell,
2. visual dashboard home screen with Today cards, Soon rows, Areas navigation, clickable upcoming
   order and low-inventory cards, and bottom quick navigation,
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
16. stock batches with expiry dates,
17. expiry table for remaining stock batches,
18. expiry-driven low inventory alerts,
19. one-month upcoming expiry alerts,
20. stock batch quantity, amount, and expiry editing,
21. stock batch combining when added stock has the same expiry date and amount,
22. stock batch deletion from inventory detail,
23. oldest-expiry-first stock consumption,
24. compatible unit conversion for stock adjustment and stock usage,
25. searchable active inventory list with attention-first ordering inside search results,
26. inventory detail pencil edit and visible action chips for history, use, and adjust,
27. inventory aliases for purchase bill names, brand names, abbreviations, and local ingredient
    names,
28. bundled baking catalog config for future purchase bill filtering,
29. purchase bill text parsing into draft inventory candidates,
30. local Apple Vision OCR service for purchase bill text recognition,
31. purchase bill draft review and save into inventory,
32. purchase bill camera capture into editable inventory drafts,
33. purchase bill photo retake and selected-photo preview,
34. purchase bill photo library import,
35. duplicate matching for purchase bill draft save,
36. local expiry reminder notifications for stock expiring within one month,
37. owner-selected currency setting for money display,
38. recipe list,
39. recipe creation with name and owner notes,
40. recipe paper/book photo import into editable drafts,
41. local Apple Vision OCR service for recipe text recognition,
42. recipe detail view,
43. manually linked recipe ingredient rows with quantity, unit, and note,
44. recipe ingredient editing and deletion,
45. structured recipe import drafts with parsed ingredient rows,
46. simple inventory matching for imported recipe ingredients,
47. recipe name and notes editing from recipe detail,
48. customer list,
49. manual customer creation,
50. customer detail view,
51. customer duplicate warning,
52. customer important dates,
53. customer editing from detail,
54. Contacts import into editable customer drafts,
55. customer detail order history for linked orders,
56. customer deletion from detail after confirmation,
57. regular-width iPad customer list/detail split view,
58. orders list,
59. order creation,
60. order detail view,
61. optional customer record link from orders,
62. searchable customer record selection from order add/edit,
63. new customer creation from order customer selection,
64. order due date/time, status, fulfillment type, delivery address, cake notes, and cake message,
65. order editing from detail,
66. manual order status changes,
67. orders Active tab grouped by due day with delivery or pickup time ordering,
68. linked customer allergies, dietary restrictions, preferences, and notes in order detail,
69. in-app order reminder planning for three, two, and one day before due date with one next
    relevant reminder shown in the UI,
70. optional saved recipe link from order add/edit,
71. linked recipe name in order detail,
72. status changes from order detail without opening the full edit form,
73. owner-confirmed linked recipe usage when a Confirmed order is marked Ready or Completed,
74. recipe-driven inventory deduction with unit conversion, recipe scaling, and
    oldest-expiry-first batch usage,
75. order-specific extra ingredients from order form or linked recipe detail, with inventory-backed
    deduction during recipe usage,
76. order detail checklist item add, edit, complete/incomplete toggle, entry-order display, and
    deletion,
77. regular-width iPad order list/detail split view,
78. optional saved cake design link from order add/edit,
79. simple Completed orders tab for completed and cancelled orders ordered by delivery or pickup
    date-time descending,
80. linked design name, notes, and photo reference in order detail,
81. completed order tab that keeps completed and cancelled orders out of active order views, with
    cancelled rows visibly marked,
82. owner-entered order quoted price, deposit paid, derived balance due, payment status, and payment
    notes,
83. visible order row actions for quick status changes and payment recording,
84. order detail payment status actions for marking Paid or adding a partial payment,
85. scheduled local owner notifications for Confirmed, In Progress, and Ready order reminders,
86. due-time order notifications that route back to the matching order,
87. overdue order row pills and an in-app update-status banner for the earliest overdue order,
88. local order photo metadata and app-owned local photo file storage,
89. order detail photo groups for customer reference photos and final cake photos,
90. photo library import for order reference and final cake photos,
91. camera capture for order reference and final cake photos,
92. full-screen preview for saved order photos,
93. caption editing for saved order photos,
94. promotion of final cake photos into linked saved cake designs,
95. saved order photo deletion from order detail,
96. Settings inventory CSV import and export for active inventory and stock batches,
97. Reminders screen with payment due WhatsApp/Mark as Paid actions, today's orders, low inventory
    sections, and detail routing,
98. shared CloudBake visual styling for second-level Orders, Inventory, Recipes, Customers, Designs,
    and Settings screens, with compact title headers and grouped Inventory header actions,
99. native iOS push navigation with short recent-page history and left-edge swipe back to the
    previous screen,
100. shared CloudBake visual styling for order, inventory, recipe, and customer detail screens,
101. shared CloudBake visual styling for owner-facing create, edit, import, and correction forms,
102. centered CloudBake confirmation popups for order, customer, and inventory actions,
103. unit, integration, and feature-sharded acceptance test lanes.

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
