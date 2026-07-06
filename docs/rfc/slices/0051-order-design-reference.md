# Slice RFC-0051: Order Design Reference

## Status

Implemented

## Parent RFC

`docs/rfc/orders.md`

## Authority And Scope

This slice lets an owner link one existing cake design reference to an order and review that
reference from order detail.

This slice applies to:

- loading saved cake designs for order add/edit,
- selecting or clearing one linked design reference,
- persisting the linked `cake_design_id` already present on orders,
- showing linked design name, notes, and photo reference in order detail.

This slice does not cover:

- creating or editing cake designs,
- capturing new cake photos from an order,
- storing image binaries,
- multiple design references per order,
- customer-facing design selection,
- AI-assisted design suggestions.

## Requirements

- Order add/edit must allow selecting an existing cake design when saved designs exist.
- Order add/edit must allow clearing the design link.
- Design selection must be searchable by useful owner-facing design text.
- Saving an order must persist the selected design link.
- Editing an order must preserve or update the selected design link.
- Order detail must show the linked design reference.
- If the linked design has notes or a photo reference, order detail must show them.
- The slice must reuse the existing `CakeDesign` model and `orders.cake_design_id`.

## Design

`CakeDesignRepository` now exposes `fetchCakeDesigns()` so order forms can load saved design
references. The GRDB implementation returns designs ordered by name.

`OrderListViewModel` now keeps:

- loaded `cakeDesigns`,
- `selectedOrderCakeDesign`,
- `draftCakeDesignId`.

The order form adds a Design section when designs exist. The selection flow follows the existing
customer and recipe selector pattern with a clear "No Linked Design" row and searchable design rows.

Order detail adds a Design section that shows:

- reference name,
- notes when present,
- photo reference when present.

## Persistence

No migration is required. The orders table already has `cake_design_id` from the core model, and
the cake designs table already stores `name`, `notes`, and `photo_reference`.

## Test Plan

- View model tests verify:
  - order load includes saved designs,
  - design selection state and search,
  - add order persists `cakeDesignId`,
  - begin viewing an order loads the linked design,
  - edit order preloads and saves the design link.
- Persistence tests verify saved cake designs can be listed.
- Acceptance tests verify an owner can select a saved design from the order form and see the linked
  design reference in order detail.

## Owner Workflow

The owner can now connect an order to an existing cake design memory while adding or editing the
order. Order detail surfaces the design reference during preparation without mixing it into recipe,
checklist, reminder, or pricing behavior.

## Future Work

- Design library screens for creating and editing saved designs.
- Order-specific customer reference photos.
- Final cake photos captured from completed orders.
- Multiple photo/reference rows per order.
- Customer-safe design browsing for future consumer surfaces.
