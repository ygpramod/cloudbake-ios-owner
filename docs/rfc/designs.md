# Designs RFC

## Status

Proposed

## Authority And Scope

This RFC is the product and engineering authority for the owner-side Designs experience in the
CloudBake iOS owner app. Implementation slice RFCs for Designs must reference this document and
record any deliberate change to its decisions.

This RFC applies to:

- a visual library of cake designs and inspiration,
- clear provenance for every saved image,
- owner-made designs, customer references, and internet inspiration,
- search, filters, tags, favourites, and usage history,
- design detail and photo viewing,
- starting a new order from a design,
- future customer-safe design browsing.

This RFC does not cover:

- AI-generated cake images,
- automatic design improvement suggestions,
- automatic web scraping or internet image search,
- public likes or social engagement,
- customer accounts or a consumer-facing app,
- cloud media storage or backend sync,
- image editing, filters, background removal, or compositing,
- copyright licensing decisions for third-party images.

Those capabilities require separate RFCs because they introduce different privacy, ownership,
technical, and product boundaries.

## Product Intent

Orders are the operational side of CloudBake. Designs should be the visual and emotional side: a
beautiful, calm place where the owner can remember completed work, understand what customers have
asked for, collect inspiration, and quickly turn an idea into a new order.

The library must preserve where an image came from. A cake made by the owner is not the same as a
customer-supplied reference or an image saved from the internet. CloudBake must never blur those
meanings, especially when a future consumer-facing portfolio is introduced.

## Product Goals

Designs should help the owner answer:

1. what cakes have I made before,
2. what references have customers shared,
3. what inspiration have I saved,
4. can I find a design quickly by colour, theme, occasion, or tag,
5. which designs have been used for prior orders,
6. can I use this design as the starting point for a new order,
7. which owner-made designs may eventually be safe to publish to customers.

The experience should prioritize photographs over text and remain practical for handmade cakes.

## Requirements Summary

- The app must provide one Designs screen with three clearly separated sources:
  - My Designs,
  - Customer References,
  - Internet Inspiration.
- The Designs screen must show the item count for each source.
- The screen must provide search across the saved design library.
- Search must match name, colour, theme, occasion, and tags.
- The screen must provide horizontally scrolling filter chips.
- Initial filters should include All, Birthday, Wedding, Kids, Cupcakes, Chocolate, Minimal,
  Vintage, and Floral when matching designs exist.
- Design results must use a photo-first grid with minimal supporting text.
- Each design card must show its name, owner favourite state, and derived order usage count.
- Opening a design must show a large photo, design name, tags, and linked order usage.
- The design detail must provide Use for New Order.
- Use for New Order must open a new order draft with the selected design already linked.
- The owner must review and save the order; selecting a design must not create an order silently.
- The app must preserve image provenance and must not present customer or internet images as work
  made by the owner.
- The experience must remain local-first and usable without a backend.

## Information Architecture

The Designs screen title is `Designs`. Its default presentation is `Inspiration + My Designs` and
contains three source sections:

1. `My Designs (count)`
2. `Customer References (count)`
3. `Internet Inspiration (count)`

Each section shows a horizontally scrollable preview row or compact grid of recent images. Tapping
the section title or a See All action opens the complete collection for that source. The initial
screen should not attempt to render hundreds of full-resolution images at once.

Search and filters apply across all three sources by default. When the owner enters a source
collection, search is scoped to that source while preserving the same search and filter language.

## Design Sources And Provenance

### My Designs

My Designs contains cakes made by the CloudBake owner. A design can enter this collection when:

- a final cake photo is promoted from an order,
- the owner adds a completed design directly,
- a future migration imports an existing owner portfolio.

Only owner-made designs may be candidates for a future public portfolio. Promotion from an order
should preserve the relationship to the final cake photo and order instead of duplicating the
image unnecessarily.

### Customer References

Customer References contains images supplied by customers for an order. The collection is derived
from order photos whose kind is `customerReference`.

Customer reference images:

- remain private owner data,
- retain their relationship to the originating order and customer when available,
- must not be labelled as owner-made work,
- must not be published to future consumer surfaces by default,
- may be reused as a reference for a new order without altering the original order.

Deleting an order reference photo must remove it from this collection. Deleting a customer record
must not silently delete an order or its historical reference photos.

### Internet Inspiration

Internet Inspiration contains third-party cake images deliberately saved by the owner. The initial
implementation may accept an image from the photo library or share/import flow and optional source
information. It must not crawl the internet automatically.

Internet inspiration should support:

- optional source URL,
- optional source or creator name,
- optional owner notes,
- the same searchable design metadata as other sources.

Internet images must remain private inspiration by default and must not be presented as owner work
or published in a future consumer portfolio without an explicit, separately designed rights and
publication workflow.

## Search

Search is a first-class control and must be visible near the top of the Designs screen.

A query such as `Blue` should match designs with:

- Blue in the name,
- Blue as a colour,
- Blue in a theme or occasion,
- Blue in a tag,
- Blue in owner-entered notes when notes are included in the search index.

Search requirements:

- matching must be case-insensitive,
- leading and trailing whitespace must be ignored,
- multiple terms should narrow results using understandable AND-style matching,
- results should update as the owner types,
- clearing the query must restore the current source and filter view,
- an empty result must explain that no saved designs match and allow filters to be cleared,
- search must not perform image recognition or remote web search in the first implementation.

Search results remain visually grouped or labelled by source so provenance is never lost.

## Filters And Tags

The default filter is All. Filters appear as horizontally scrolling pastel chips below search.

The initial suggested chips are:

- Birthday,
- Wedding,
- Kids,
- Cupcakes,
- Chocolate,
- Minimal,
- Vintage,
- Floral.

These labels are not separate hard-coded business models. They are convenient views over structured
occasion, theme, category, flavour, and tag metadata. The UI should avoid showing empty chips when
doing so would add noise.

The owner must eventually be able to add and remove free-form tags. Normalization should prevent
case-only duplicates such as `Floral` and `floral` while preserving a consistent display value.

The first filtering slice may support one selected chip at a time. Multi-filter composition can be
added later if actual owner use demonstrates the need.

## Design Grid And Cards

The library must be photograph-led. Cards should contain:

- a large thumbnail,
- design name,
- a favourite control or state,
- order usage count such as `Used 7x` when usage exists,
- a subtle source marker when the surrounding collection does not already make provenance clear.

The usage count must be derived from orders linked to the design; it must not be manually entered.

Because the first app has one owner, the heart represents the owner's favourite state rather than
a numeric public like count. A count such as `18 likes` would imply consumer engagement that does
not exist. Public popularity metrics belong to a future consumer RFC.

Cards must remain readable with long names and Dynamic Type. The photo area should keep a stable
aspect ratio so image loading does not move the grid.

## Design Detail

Opening a design presents a photo-first detail experience with:

- a large edge-to-edge photo,
- smooth pinch-to-zoom,
- swipe navigation to adjacent designs in the current result set,
- design name,
- provenance,
- favourite state,
- colour, theme, occasion, and free-form tags,
- optional owner notes,
- source information when applicable,
- a Used In section,
- a Use for New Order action.

The Used In section lists linked orders using useful owner-facing identity, such as cake name and
due date. Raw order numbers may be shown when CloudBake has a stable owner-facing order number, but
the relationship must use stable order ids internally.

Customer reference detail should show its originating order when available. Internet inspiration
detail should show source information when recorded. Owner-made designs may show the completed
orders that used or produced the design.

## Use For New Order

Use for New Order is a primary workflow, not a decorative link.

When selected:

1. CloudBake opens the add-order form using normal forward navigation.
2. The selected design is pre-linked to the draft.
3. The owner may select or create a customer and enter all required order details.
4. The owner may add order-specific design notes or minor requested changes.
5. The original design and its metadata remain unchanged.
6. No order is persisted until the owner explicitly saves.

The workflow must work for all three sources. The order must retain enough provenance to explain
whether the linked reference was owner-made, customer-supplied, or internet inspiration.

## Visual And Interaction Direction

Designs should use the established CloudBake visual language while feeling more photographic than
operational screens.

The intended direction is:

- large, high-quality photos,
- approximately 24-point photo corners where the established component allows it,
- white background in the current light-only app appearance,
- soft restrained shadows,
- pastel category chips,
- minimal text,
- generous whitespace,
- smooth grid, swipe, and zoom transitions,
- consistent bottom navigation and native back-swipe behavior,
- no repeated CloudBake logo in the screen header.

This direction does not permit deeply nested cards, unstable custom navigation, unreadable text,
or loading full-resolution images into every grid cell.

On iPhone, the grid should optimize for browsing with one hand. On iPad, the library may use more
columns and a list/detail or gallery/detail presentation while preserving the same source and
search model.

## Domain Model Direction

The current `CakeDesign` model is the starting point and should evolve rather than being replaced
without a migration plan.

A design library item should eventually represent:

- stable id,
- name,
- source kind: owner made, customer reference, or internet inspiration,
- primary photo reference,
- optional originating order photo id,
- optional originating order id,
- optional source URL and source name,
- optional notes,
- colour values,
- themes,
- occasions,
- tags,
- favourite state,
- created and updated timestamps,
- future publication eligibility and publication state for owner-made designs only.

Order usage count is derived and should not be stored as mutable design metadata unless a later
performance slice introduces a safely maintained projection.

The implementation must avoid duplicating business rules between Designs and Orders. Order links
remain the authority for usage, and order photos remain the authority for their photo kind and
origin.

## Photo Storage And Lifecycle

- Image binaries must not be stored in SQLite.
- The database should store stable metadata and app-relative paths or Photos asset identifiers.
- Grid views must use generated or cached thumbnails rather than decoding full-resolution images.
- Detail views may load a larger representation on demand.
- Missing, moved, or deleted photo assets must show a recoverable placeholder rather than crash.
- Removing a design record must not delete an order or its final/customer photo without a separate
  explicit owner decision.
- Orphan cleanup and storage migration require a dedicated implementation slice.

## Privacy, Ownership, And Future Publication

Design provenance is a privacy and trust boundary.

- Customer reference photos are private by default.
- Internet inspiration is private by default.
- Owner notes are private by default.
- Only owner-made designs may become public portfolio candidates.
- A future publication workflow must require explicit owner selection.
- Future consumer projections must exclude customer identity, private order details, notes, source
  URLs that should remain internal, and any image without publication permission.

CloudBake should not claim ownership of customer or internet images merely because they are stored
in the app.

## Non-Functional Requirements

### Performance

- The Designs screen must remain responsive with several hundred saved images.
- The initial screen must lazy-load visible thumbnails.
- Search and filters should update without blocking the main thread.
- Full-resolution image decoding must happen away from scrolling-critical work.
- Thumbnail caching must have a bounded storage policy in a later implementation slice.

### Reliability

- Design provenance must survive app restarts and migrations.
- Starting an order from a design must not mutate the source design.
- Usage count must remain consistent with persisted order links.
- Existing `CakeDesign` and order design links must remain valid through schema evolution.
- Repeated promotion of the same final photo should warn or prevent accidental duplicate designs.

### Accessibility

- Every photo and icon action must have an accessibility label.
- Favourite, source, and selected filter states must not rely on colour alone.
- Pinch-to-zoom must have an accessible alternative for viewing the full photo.
- Cards and controls must remain usable with Dynamic Type and VoiceOver.
- Touch targets must meet platform guidance.

### Offline And Data Ownership

- Saved designs, search, filters, detail, and Use for New Order must work offline.
- The owner retains control over imported photos and metadata.
- The first implementation must not require a CloudBake backend or subscription.

### Testing

- Search, filter, source classification, favourite state, and usage derivation require unit tests.
- Schema migrations and design/order/photo relationships require integration tests.
- Critical browse, search, detail, and Use for New Order workflows require focused acceptance tests.
- Photo picker and camera system UI should use unit-level routing plus manual device testing when
  stable CI automation is not practical.
- Performance tests should cover thumbnail-heavy scrolling and search over a representative local
  library before the feature is considered complete.

## Relationship To Existing Features

The current app already provides foundations that this RFC must preserve:

- orders can link to one `CakeDesign`,
- order detail can store customer reference and final cake photos,
- final cake photos can be promoted into the design library,
- the bottom navigation already exposes Designs,
- future consumer order previews can expose safe design name and photo data.

The Designs implementation should extend these foundations into a coherent library instead of
creating a second, disconnected photo system.

## Recommended Implementation Slices

1. Design Library Data Model And Provenance Migration
2. My Designs Gallery And Design Detail
3. Customer References Collection
4. Internet Inspiration Import And Source Metadata
5. Design Search
6. Design Tags, Filters, And Favourites
7. Design Usage History
8. Use Design For New Order
9. Design Photo Zoom, Swipe, And Thumbnail Performance
10. iPad Designs Gallery And Detail Layout
11. Future Consumer-Safe Design Projection

Each implementation slice must have a focused RFC under `docs/rfc/slices/`, meaningful unit and
integration tests, impacted acceptance coverage, and wiki updates when owner workflow truth changes.

## First Slice Recommendation

The first slice should establish provenance safely before building the full gallery:

- extend the existing `CakeDesign` model with source kind,
- migrate existing promoted final-photo designs as owner-made,
- preserve existing order links and photo references,
- define repository queries by source,
- add unit and persistence integration tests,
- avoid changing the visible placeholder Designs screen until the model is trustworthy.

The second slice can then build My Designs browsing and detail on top of stable data.

## Decisions

- The library is separated by image provenance.
- The owner MVP uses My Designs, Customer References, and Internet Inspiration.
- Search is local and metadata-based in the first implementation.
- Search covers name, colour, theme, occasion, and tags.
- Filters are convenient metadata views, not separate duplicate classification systems.
- Owner favourite is a Boolean state; public like counts are not part of the owner MVP.
- Used count is derived from linked orders.
- Use for New Order opens an unsaved draft with the design pre-linked.
- Customer and internet images remain private by default.
- AI-assisted suggestions and automatic web search are deferred.

## Open Questions

- Should the Designs landing screen show only a short recent preview for each source, or allow each
  source section to expand inline?
- When importing internet inspiration, should source URL be optional or required when the image is
  shared from a browser?
- Should deleting an internet inspiration item remove its app-owned image immediately or move it to
  a short recovery period?
- Should colour metadata begin as free-form tags or a controlled colour picker with optional custom
  names?
- Should Use for New Order preserve the source design as the only linked reference, or also copy a
  snapshot into the new order to protect historical appearance if the design is edited later?
