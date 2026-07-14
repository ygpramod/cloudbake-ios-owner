# Slice RFC-0110: On-Device Voice Inventory Drafts

## Status

Implemented

## Context

Entering several purchased ingredients one form at a time is slow. The owner needs a hands-free
starting point that turns spoken item, quantity, and unit phrases into editable inventory drafts
without sending bakery data or audio to a remote recognition service.

## Scope

1. Add an inventory action that opens an editable voice transcript and draft workflow.
2. Recognize speech with Apple's on-device speech recognizer in the current iPhone language.
3. Parse repeated arbitrary item names followed by a positive quantity and supported unit.
4. Match saved inventory names and aliases before proposing a new item.
5. Require an owner decision for every unknown item: map it to existing inventory or create it.
6. When mapped, add the spoken name as an alias and add a converted stock batch.
7. Allow quantity, unit, minimum quantity, and expiry review before saving.

Network speech recognition, background listening, and cloud transcription are outside this slice.

## Privacy And Availability

1. `requiresOnDeviceRecognition` is mandatory; there is no server fallback.
2. Audio and transcripts remain on the iPhone.
3. Microphone and speech-recognition permission are requested only when listening starts.
4. If the current iPhone language does not support on-device recognition, the workflow explains
   that limitation and still permits manual transcript entry.

## Draft And Mapping Rules

1. A complete phrase contains an arbitrary item name, positive number, and supported unit.
2. Supported units include kg, g, L, ml, tsp, tbsp, cups, pieces, and common spoken variants.
3. Automatic matching requires exactly one case-insensitive exact name or alias match. Partial or
   ambiguous matches require an owner decision.
4. Mapping choices show only inventory with a compatible measurement family.
5. Unknown drafts cannot be saved until the owner maps or creates them.
6. Mapping preserves the saved inventory unit and converts the draft quantity before adding stock.
7. New and mapped stock uses the item-level expiry default when available, while remaining
   editable or removable in the draft.
8. All items, aliases, quantities, and stock batches from one voice import save atomically.
9. Editing a draft name re-evaluates its destination and requires a new decision when it no longer
   has one unique exact match.

## Testing

Focused tests cover multi-item parsing, unique and ambiguous alias matching, name-edit destination
invalidation, unknown-item decisions, alias creation, stock updates, atomic rollback, expiry
removal, recognition-session cancellation, and unresolved-draft validation. A targeted acceptance
test enters a transcript without invoking microphone permissions, updates existing stock, creates
an unknown item, and verifies both results. Real microphone and Apple permission dialogs remain
device-tested boundaries.

## Documentation Decision

This slice adds an owner-facing inventory workflow and a durable on-device privacy boundary, so the
Inventory Guide, Owner Workflows, Business Concepts, Current App Capabilities, repository README,
and this slice RFC are updated.
