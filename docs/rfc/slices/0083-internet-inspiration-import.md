# Slice RFC-0083: Internet Inspiration Import

## Status

Implemented

## Parent RFC

- `docs/rfc/designs.md`

## Context

The owner needs a private place for deliberately saved third-party cake inspiration without
misrepresenting it as bakery work or copying image binaries into CloudBake storage.

## Scope

1. Add optional source/creator name and source URL metadata to persisted designs.
2. Import an image selected explicitly by the owner from Photos.
3. Reuse the selected Photos asset identifier when available; save fallback image data to Photos.
4. Validate optional source URLs as http or https addresses.
5. Show a counted Internet Inspiration collection and photo-only thumbnails.
6. Show name, provenance, source, URL, and notes in detail.
7. Search internet inspiration across name, notes, source, and URL.

Out of scope:

1. Automatic web search, crawling, or downloading.
2. Rights or publication approval.
3. Deleting the underlying Photos asset.

## Design

Internet inspiration uses `CakeDesignSourceKind.internetInspiration` and remains private. CloudBake
stores metadata plus a Photos local identifier only. Selecting an existing Photos asset does not
create another copy. Source metadata is optional, but malformed entered URLs are rejected.

## Test Strategy

1. View-model tests cover metadata normalization, URL validation, and cross-field search.
2. Persistence integration round-trips source metadata.
3. Existing PhotoKit ownership, missing-asset, and bounded-image coverage remains active.

## Documentation Decision

The wiki is updated because Internet Inspiration is now an owner-facing workflow. The parent RFC is
also updated to record the owner's photo-only thumbnail decision.
