# Slice RFC-0089: Design Photo Navigation And Performance

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The photo-first library needs closer inspection and quick movement through adjacent results without
loading full-resolution images into every grid cell or breaking the landing screen's vertical
scrolling.

## Scope

1. Support pinch zoom from 1× through 4× and bounded two-axis pan on design and
   customer-reference detail photos.
2. Provide labelled Zoom In, Zoom Out, and Reset Zoom controls as the accessible alternative.
3. Swipe horizontally between adjacent items in the current filtered source collection.
4. Preserve vertical detail and landing-screen scrolling by accepting only strongly horizontal
   adjacent-item gestures.
5. Continue loading bounded, cached thumbnails for grids and larger images only on detail.
6. Exercise local search across several hundred design records in a performance test.

## Design

The detail view owns zoom state per stable item identity, so navigating resets the next photo to
1×. Pan is bounded to the scaled photo and adjacent navigation is suppressed while zoomed.
Previous and Next controls provide an accessible alternative to horizontal swipes, and VoiceOver
receives the current zoom percentage. Adjacent navigation retains the filtered collection snapshot
that opened detail, so changing a favourite or tag does not strand the current item. Thumbnail
loading remains actor-isolated with count and memory-cost limits; detail requests a larger
representation on demand.

## Test Strategy

1. Focused acceptance proves zoom controls are exposed and a swipe opens the adjacent result.
2. A GRDB-backed performance budget loads and searches 600 persisted records using a multi-term
   query in under one second.
3. Acceptance covers zoom state, navigation boundaries, filtered adjacency, and scrolling from the
   bottom of Designs back to search.

## Documentation Decision

README and wiki source are updated because zoom and adjacent browsing are new owner-visible
workflows.
