# Slice RFC-0084: Design Library Search

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The three Designs sources need one predictable local search language while remaining visually
grouped so provenance is never lost.

## Scope

1. Keep search visible above all three source collections.
2. Normalize case, surrounding whitespace, and punctuation locally.
3. Tokenize multiple terms and require every term to match some indexed field.
4. Allow terms to match across different fields on the same item.
5. Search owner designs by name and notes, customer references by caption/order/customer, and
   internet inspiration by name/notes/source/URL.
6. Preserve source grouping and provide a clear no-results state.
7. Exclude opaque Photos identifiers from owner-facing search.

Out of scope:

1. Image recognition or remote web search.
2. Tags and structured filter metadata, introduced by the next slice.
3. Search ranking or fuzzy spelling correction.

## Test Strategy

View-model tests cover case-insensitive partial matching, cross-field multi-term AND behavior,
group scoping, and empty results. Existing source-projection tests prove provenance grouping.

## Documentation Decision

The wiki is updated because cross-source Designs search is now an owner-facing workflow.
