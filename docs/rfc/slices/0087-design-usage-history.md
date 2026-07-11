# Slice RFC-0087: Design Usage History

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The owner needs to understand whether a saved design has been used and open useful historical
context without maintaining a counter that can drift from orders.

## Scope

1. Derive saved-design usage exclusively from orders whose `cakeDesignId` matches the design.
2. Show a compact usage-count overlay on photo-only thumbnails when usage exists.
3. Show linked order title and due date in design detail.
4. Sort usage history by latest due date first with deterministic title fallback.
5. Treat the originating order as the usage context for a derived Customer Reference.
6. Expose usage count to VoiceOver.
7. Prevent promoting the same final order photo into duplicate saved designs.

## Design

No usage count is persisted. Orders remain the authority, so linking, unlinking, or deleting design
metadata updates derived history naturally. Repeated final-photo promotion is rejected by stable
originating photo id before any Photos or database write.

## Test Strategy

1. View-model tests prove linked-only counting and deterministic history order.
2. Order photo tests prove repeated promotion creates neither a second Photos asset nor design.
3. Existing persistence tests cover stable order/design links and unlink-on-design-removal.

## Documentation Decision

The wiki is updated because usage context is now visible in Designs.
