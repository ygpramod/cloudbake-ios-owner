# Slice RFC-0124: Voice Inventory Guidance

## Status

Implemented

## Context

The Add Inventory by Voice screen accepts structured speech, but the required phrase format is not
discoverable from the screen itself. Its large navigation title also diverges from CloudBake's
other form screens.

## Scope

1. Add an information control beside the Voice Inventory section heading.
2. Expand concise phrase guidance and examples inline in the form rather than presenting another
   popup.
3. Explain that each phrase needs an item name, quantity, and unit and that a pause starts the next
   item on a new line.
4. Keep the guidance collapsed by default so the transcript remains the primary control.
5. Use the standard inline navigation-title size used by other CloudBake form screens.

## Accessibility

The information control has a state-aware accessibility label. The expanded guidance is exposed as
one identifiable reading group and remains compatible with Dynamic Type.

## Testing

The existing voice-inventory acceptance workflow verifies that the guidance starts collapsed,
expands from the information control, and presents an example before continuing through draft
creation.

## Documentation Decision

This is durable owner-visible workflow guidance, so the Inventory Guide and Owner Workflows wiki
sources are updated in the same slice.
