# Slice RFC-0125: Purchase Bill Crop And Reading Order

## Status

Implemented

## Context

Apple Vision can recognize unrelated text around a purchase bill and may return separate text
regions in an order that does not match the printed receipt lines. That makes the editable bill
text noisy and reduces the quality of inventory drafts.

## Scope

1. Present a crop review after taking a bill photo or choosing one from Photos.
2. Let the owner move and resize the crop, reset it, cancel without replacing the prior bill, or
   confirm it before recognition begins.
3. Keep recognition local with Apple Vision.
4. Reconstruct recognized text geometrically: group vertically overlapping boxes into rows, sort
   rows from top to bottom, and sort text inside each row from left to right.
5. Keep recognized bill text editable and retain manual entry as the fallback.
6. Use readable shared section-heading typography for Bill Photo, Bill Text, Voice Inventory, and
   both draft sections against the import-screen background.

## Out Of Scope

1. Perspective correction or automatic receipt-edge detection.
2. Sending bill photos or recognized text to a server or generative model.
3. Persisting the bill image after inventory drafts are saved.

## Accessibility

Crop handles have descriptive accessibility labels, crop controls use text labels, and import
section headings use the app's high-contrast shared typography.

## Testing

1. Unit tests verify top-to-bottom row ordering, left-to-right ordering within a row, tolerance for
   slightly misaligned recognition boxes, and removal of empty regions.
2. Unit tests verify normalized crop dimensions and clamping at image bounds.
3. The focused inventory acceptance test verifies the purchase-bill screen still exposes camera,
   photo-library, editable-text, and draft controls.

## Documentation Decision

This changes an owner-visible inventory workflow, so the Inventory Guide, Owner Workflows, and
Current App Capabilities wiki sources are updated in the same slice.
