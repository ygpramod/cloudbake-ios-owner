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
52. orders list,
53. order creation,
54. order detail view,
55. optional customer record link from orders,
56. searchable customer record selection from order add/edit,
57. order due date/time, status, fulfillment type, delivery address, and cake notes,
58. order editing from detail,
59. manual order status changes,
60. orders calendar view grouped by due date,
61. linked customer allergies, dietary restrictions, preferences, and notes in order detail,
62. unit, integration, and acceptance test lanes.

## Partially Prepared

The app has domain foundations or partial workflows for:

1. recipe components and ingredients,
2. cake designs,
3. pricing,
4. order delivery reminders,
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
3. recipe-driven inventory reduction,
4. order calendar,
5. delivery reminders,
6. cake photo storage,
7. pricing calculator,
8. order recipe usage and inventory deduction,
9. customer-facing cake browsing,
10. sync through iCloud or backend when needed.

## Source References

Detailed implementation truth lives in:

1. `README.md`,
2. `docs/engineering-guardrails.md`,
3. `docs/adr/`,
4. `docs/rfc/slices/`,
5. app and test source files.
