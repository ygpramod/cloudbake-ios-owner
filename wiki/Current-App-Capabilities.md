# Current App Capabilities

## Help and first launch

- A new installation presents a five-page introduction to Home, Orders, Inventory, the bakery
  library, and backup. The owner can move with **Next**, leave with **Skip**, or finish with
  **Get Started**.
- **Settings → Help & Guide** provides offline guidance for the app's main workflows and can replay
  the introduction at any time.

This page lists what the app currently supports. It should stay factual and product-focused.

## Available Now

The app currently supports:

1. native iPhone app shell,
2. visual dashboard home screen with Today, Needs attention, and Quick actions sections, clickable
   upcoming order and attention rows, a today-through-day-30 Upcoming Orders window, and bottom
   quick navigation for Home, Orders, Inventory, and More,
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
73. customizable in-app order reminder planning, with owner defaults copied to new orders and
    per-order default, custom, or disabled plans,
74. optional saved recipe link from order add/edit,
75. linked recipe name in order detail,
76. status changes from order detail without opening the full edit form,
77. owner-confirmed linked recipe usage when an order is marked Ready or Completed, without a Draft
    or In Progress bypass,
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
84. linked design name, notes, tappable photo thumbnail, and full-screen photo detail in order
    detail,
85. completed order tab that keeps completed and cancelled orders out of active order views, with
    cancelled rows visibly marked,
86. owner-entered order quoted price, deposit paid, derived balance due, payment status, and payment
    notes,
87. visible order row actions with native menus for quick status changes and payment recording,
88. order detail payment status actions for marking Paid or adding a partial payment,
89. scheduled local owner notifications for Confirmed, In Progress, and Ready orders using each
    order's saved reminder plan,
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
106. native iOS alerts and confirmation dialogs for protected order, customer, inventory, recipe,
    design, reminder, backup, restore, and data-management actions,
107. unit, integration, and feature-sharded acceptance test lanes.
108. persisted cake-design provenance for owner-made and customer-reference workflows, with
    historical internet-inspiration provenance retained privately for migration safety.
109. an owner-made My Designs photo gallery and design detail view backed by referenced Photos
    assets, with explicit handling when an asset is unavailable.
110. Photos-owned design images: CloudBake saves newly promoted designs to the iPhone Photos
    library and stores only the returned local asset identifier, while retaining read-only legacy
    reference compatibility.
111. a private References collection in Designs containing only photos the owner imports or
    explicitly adds from an order customer-reference photo, without automatically mirroring order
    uploads.
112. Photos-owned order images: new customer-reference and final-cake photos are saved to Photos,
    and order metadata stores only the returned asset identifier.
113. retired Internet Inspiration records remain private and excluded from the current owner UI,
    order selection, and future consumer projections.
114. photo-only Designs thumbnails, with names and metadata available through accessibility and the
    centered, shared-style detail screen.
115. local cross-source Designs search with tokenized AND matching across My Designs and explicit
    References.
116. normalized design tags, represented-tag filter chips, and a private owner favourite state
    across saved designs and customer references.
117. confirmed removal of designs and References from CloudBake while preserving the underlying
    iPhone Photos asset and any originating order photo.
118. single-axis, compact Designs grids that preserve vertical scrolling through large My Designs
    and Reference collections without end-of-page oscillation.
119. derived design usage counts and linked-order history, plus duplicate final-photo promotion
    prevention based on stable originating photo identity.
120. `Use for New Order` from saved designs and References, opening the standard unsaved order
    draft with a validated design link shown explicitly on saved order detail.
121. design-detail pinch zoom with accessible zoom controls, horizontal movement through adjacent
    filtered results, bounded thumbnail caching, and representative local-search performance
    coverage.
122. a fail-closed future consumer design projection that includes only explicitly published,
    owner-made designs with an available photo and excludes private provenance and owner metadata.
123. direct My Designs import from the iPhone Photos library with required name, optional notes and
    normalized tags, storing only the Photos asset reference and private owner metadata.
124. a ten-tag, frequency-ranked Designs ribbon and a photo-first searchable Designs grid for
    linking owner-made designs or explicit References to order drafts, while retaining historical
    labels for retired Internet Inspiration links.
125. owner-selected in-app branding through a Settings photo picker, with app-managed logo storage,
    immediate dashboard refresh, and restoration of the bundled default logo.
126. owner-controlled full-app `.cloudbakebackup` export through the system Files picker, including
    the validated database, app-managed images, lightweight recovery copies of linked Photos assets,
    and custom logo, with last-success status and a default-on weekly reminder that can be disabled.
127. collapsed Settings controls for CloudKit disaster recovery, including enabled state, iCloud
    availability, last-success time, estimated size, safe status guidance, independently configurable
    notifications, and size-aware cellular confirmation for manual cloud backup.
128. owner-initiated full restore from the latest compatible CloudKit recovery snapshot, including
    preflight date, size, integrity, and compatibility inspection; Start Fresh on empty installs;
    destructive replacement and cellular confirmation; broken-photo resolution; staged migration;
    atomic activation; repeatable interrupted-activation recovery; session-safe cancellation; and
    post-restore reminder and backup reconciliation. Custom-logo-only installations require
    destructive replacement confirmation, and unresolved rollback blocks app interaction until
    restart recovery.
129. per-item default expiry days for future inventory additions, upward adjustments, and matched
    purchase-bill drafts, including inventory CSV import and export.
130. on-device voice inventory transcription into editable multi-item drafts, with saved-name and
    alias matching, owner-confirmed unknown-item mapping or creation, and no server fallback.
131. lean active inventory cards with centered Adjust and Use pills, right-swipe History,
    left-swipe Archive and Delete, and guarded permanent deletion from active or archived inventory
    that preserves linked stock, recipe, and order records.
132. owner-requested cloud backups that always create a fresh snapshot, even with unchanged app
    data, with size-aware cellular consent required separately for every manual attempt.
133. owner-confirmed Ready and Completed transitions when usable inventory is short, including
    partial non-expired deduction, persisted shortfall, non-negative stock, and full ingredient
    costing from the newest known purchase price when available.
134. owner-controlled unavailable-photo recovery for cloud and manual full backups, with one
    aggregated decision; opaque persisted omission approvals; second confirmation and immediate
    revalidation before exact CloudBake-reference removal; last-good cloud generation preservation;
    and durable omitted-photo counts without exposing raw Photos identifiers.
135. persisted full-order inventory reservations for Confirmed and In Progress work, including
    shortage confirmation, atomic replacement and release, immutable audit events, migrated-order
    repair, aggregate planning reads, and compact reserved quantities in order detail.
136. at most one aggregate Payment Pending notification per calendar day for overdue Completed
    orders with a remaining balance, using a rolling 14-day local schedule, the same eligibility as
    the in-app Payment Due list, an owner-selected reminder time, immediate refresh after
    payment/order/settings changes, and first-completion timestamps that preserve unknown legacy
    history.
137. immutable dated payment receipts for opening, partial, and remaining-balance payments, with
    atomic paid-total reconciliation, append-only void corrections, and explicit legacy payments
    whose dates are unknown.
138. a Reports screen with Payment Ledger, Order Profitability, and Sales & Orders; a rolling
    one-year default ending today; custom date ranges up to 366 days; status filters; Day, Week, and
    Month grouping where applicable; bounded row and sales-bucket drill-down; payment delay from
    order due date; partial ingredient-cost warnings; and exact receipt/sales totals.
139. user-confirmed purchase-bill cropping before local Vision recognition, geometric reconstruction
    of recognized receipt lines from top to bottom and left to right, and readable shared headings
    throughout the purchase-bill and voice-inventory forms.
140. native document-camera edge correction, generic measured-product purchase-bill drafts from the
    exact on-device OCR text, editable purchase amounts, per-row Add to Inventory controls,
    receipt-name aliases for mapped inventory, and atomic priced-batch saving.
141. three-calendar-month default expiry for Standard inventory while retaining the four-day
    Perishable default and per-item overrides.
142. Standard inventory expiry notifications fourteen days before expiry, with Perishable expiry
    notifications suppressed.
143. next-day nearest-hour defaults for new order due times and uninterrupted Ready/Completed
    status progression for orders without recipes or inventory ingredients.

## Partially Prepared

The app has domain foundations or partial workflows for:

1. recipe components and ingredients,
2. cake designs,
3. customer-safe order preview projection for future consumer-facing surfaces,
4. customer-safe profile projection for future consumer-facing surfaces,
5. order reminder snooze,
6. inventory transactions,
7. recipe ingredient quantity extraction.

These are not all owner-facing workflows yet.

## Future Product Areas

Planned product areas include:

1. stronger OCR cleanup and page correction for scanned recipes,
2. optional LLM-assisted recipe interpretation,
3. partial recipe usage,
4. multi-recipe orders,
5. order checklist reordering and templates,
6. reminder snooze,
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
