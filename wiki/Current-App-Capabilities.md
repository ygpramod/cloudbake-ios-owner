# Current App Capabilities

This page lists what the app currently supports. It should stay factual and product-focused.

## Available Now

The app currently supports:

1. native iPhone and iPad app shell,
2. dashboard navigation,
3. inventory navigation,
4. local SQLite persistence,
5. inventory item creation,
6. current quantity and minimum quantity tracking,
7. low-inventory detection,
8. duplicate inventory warning,
9. inventory item detail view,
10. inventory item editing for name and minimum quantity,
11. inventory archiving,
12. archived inventory restore,
13. stock adjustment,
14. stock consumption,
15. stock history for active inventory items,
16. stock batches with expiry dates,
17. expiry table for remaining stock batches,
18. expiry-driven low inventory alerts,
19. one-month upcoming expiry alerts,
20. stock batch quantity and expiry editing,
21. stock batch deletion from inventory detail,
22. oldest-expiry-first stock consumption,
23. compatible unit conversion for stock adjustment and stock usage,
24. inventory detail pencil edit and more-menu actions for history, use, and adjust,
25. bundled baking catalog config for future purchase bill filtering,
26. purchase bill text parsing into draft inventory candidates,
27. local Apple Vision OCR service for purchase bill text recognition,
28. purchase bill draft review and save into inventory,
29. purchase bill camera capture into editable inventory drafts,
30. purchase bill photo retake and selected-photo preview,
31. purchase bill photo library import,
32. duplicate matching for purchase bill draft save,
33. local expiry reminder notifications for stock expiring within one month,
34. recipe list,
35. recipe creation with name and owner notes,
36. recipe paper/book photo import into editable drafts,
37. local Apple Vision OCR service for recipe text recognition,
38. recipe detail view,
39. manually linked recipe ingredient rows with quantity, unit, and note,
40. recipe ingredient editing and deletion,
41. structured recipe import drafts with parsed ingredient rows,
42. simple inventory matching for imported recipe ingredients,
43. recipe name and notes editing from recipe detail,
44. customer list,
45. manual customer creation,
46. customer detail view,
47. customer duplicate warning,
48. customer important dates,
49. customer editing from detail,
50. Contacts import into editable customer drafts,
51. customer detail order history for linked orders,
52. regular-width iPad customer list/detail split view,
53. orders list,
54. order creation,
55. order detail view,
56. optional customer record link from orders,
57. searchable customer record selection from order add/edit,
58. order due date/time, status, fulfillment type, delivery address, and cake notes,
59. order editing from detail,
60. manual order status changes,
61. orders calendar view grouped by due date,
62. linked customer allergies, dietary restrictions, preferences, and notes in order detail,
63. in-app order reminder planning for three, two, and one day before due date with one next
    relevant reminder shown in the UI,
64. optional saved recipe link from order add/edit,
65. linked recipe name in order detail,
66. status changes from order detail without opening the full edit form,
67. owner-confirmed linked recipe usage when a Confirmed order is marked Ready or Completed,
68. recipe-driven inventory deduction with unit conversion and oldest-expiry-first batch usage,
69. order detail checklist item add and complete/incomplete toggle,
70. regular-width iPad order list/detail split view,
71. unit, integration, and feature-sharded acceptance test lanes.

## Partially Prepared

The app has domain foundations or partial workflows for:

1. recipe components and ingredients,
2. cake designs,
3. pricing,
4. scheduled order delivery notifications,
5. inventory transactions,
6. purchase bill filtering by baking catalog,
7. purchase bill draft inventory parsing,
8. purchase bill text recognition through Apple Vision,
9. purchase bill draft review flow,
10. purchase bill camera import flow,
11. purchase bill duplicate matching,
12. recipe ingredient quantity extraction.

These are not all owner-facing workflows yet.

## Future Product Areas

Planned product areas include:

1. stronger OCR cleanup and page correction for scanned recipes,
2. optional LLM-assisted recipe interpretation,
3. recipe scaling before usage,
4. partial recipe usage,
5. richer order checklist editing, deletion, reordering, and templates,
6. delivery reminders,
7. cake photo storage,
8. pricing calculator,
9. customer-facing cake browsing,
10. sync through iCloud or backend when needed.

## Source References

Detailed implementation truth lives in:

1. `README.md`,
2. `docs/engineering-guardrails.md`,
3. `docs/adr/`,
4. `docs/rfc/slices/`,
5. app and test source files.
