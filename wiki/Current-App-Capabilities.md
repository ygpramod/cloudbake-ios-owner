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
24. visible inventory detail actions for edit, history, use, and adjust,
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
44. unit, integration, and acceptance test lanes.

## Partially Prepared

The app has domain foundations or partial workflows for:

1. recipe components and ingredients,
2. orders,
3. customers,
4. cake designs,
5. pricing,
6. order delivery reminders,
7. inventory transactions,
8. purchase bill filtering by baking catalog,
9. purchase bill draft inventory parsing,
10. purchase bill text recognition through Apple Vision,
11. purchase bill draft review flow,
12. purchase bill camera import flow,
13. purchase bill duplicate matching,
14. recipe ingredient quantity extraction.

These are not all owner-facing workflows yet.

## Future Product Areas

Planned product areas include:

1. stronger OCR cleanup and page correction for scanned recipes,
2. optional LLM-assisted recipe interpretation,
3. recipe-driven inventory reduction,
4. customer likes, dislikes, allergies, and preferences,
5. order calendar,
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
