# Slice RFC-0065: Order Checklist Item Editing

## Status

Implemented

## Parent RFC

- `docs/rfc/slices/0048-order-checklist.md`

## Context

Order checklist items capture handmade cake preparation tasks such as crumb coat, topper pickup,
box ready, and final photo. Owners need to correct task wording after entry without deleting and
recreating the item, especially after a cake plan changes.

## Scope

In scope:

- editing an existing checklist item title from order detail,
- trimming the edited title before persistence,
- rejecting blank edited titles,
- preserving completion state, entry order, and created timestamp,
- focused unit and acceptance coverage.

Out of scope:

- checklist reordering,
- checklist templates,
- checklist-driven order status changes.

## Requirements

- The owner must be able to open checklist item editing from an existing checklist row.
- Saving must update the checklist item title without changing completion state.
- Saving must preserve the original entry order.
- Blank titles must be rejected.
- Existing add, complete/incomplete toggle, and delete behavior must continue to work.

## Design

The existing `OrderChecklistRepository.save(_:)` already upserts checklist rows, so no schema or
repository migration is needed.

`OrderListViewModel.updateChecklistItemTitle(_:title:)` validates and trims the title, then saves a
copy of the checklist item with the same id, order id, completion state, sort order, and created
timestamp. The updated timestamp uses the current date provider.

Order detail exposes visible Edit and Delete row actions. Edit opens a small sheet with a title
field and Save/Cancel actions. The row refreshes from the selected order checklist after save.

RFC-0070 replaced the original trailing swipe presentation with visible card-row actions because
order detail now uses a custom scroll-view layout rather than a native `List`.

## Testing

Focused tests cover:

- title edit persistence,
- trimming,
- blank title rejection,
- preserving completion state and entry order,
- the owner acceptance path for add, edit, complete, and delete.

## Follow-Up

- Add checklist reordering.
- Add reusable checklist templates.
