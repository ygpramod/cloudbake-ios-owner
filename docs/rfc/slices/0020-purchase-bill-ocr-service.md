# Slice RFC-0020: Purchase Bill OCR Service

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Add the local OCR boundary needed to extract text from purchase bill images before bill draft
parsing.

## Scope

- Add a `PurchaseBillTextRecognizing` protocol.
- Add a `VisionPurchaseBillTextRecognizer` implementation backed by Apple Vision.
- Recognize text from `CGImage`.
- Return recognized text as newline-separated lines.
- Keep OCR out of SwiftUI views and domain parsing code.
- Update README and wiki product documentation.

## Out of Scope

- Camera or document scanner UI.
- Photo picker UI.
- Owner draft review UI.
- Saving purchase bill drafts into inventory.
- OCR accuracy tuning by vendor or receipt layout.
- Cloud OCR, AI, or LLM document analysis.

## Requirements

- OCR must run locally on device through Apple Vision.
- The app must not require an OCR subscription or per-scan external service for the first version.
- The OCR boundary must be injectable so future view models can use a fake recognizer in tests.
- Recognized text must be returned in a shape compatible with `PurchaseBillDraftParser`.

## Design

### Protocol

`PurchaseBillTextRecognizing` defines:

- `recognizedText(from:) async throws -> String`

This lets future UI and view-model code depend on a small app-owned boundary instead of directly on
Vision APIs.

### Vision Implementation

`VisionPurchaseBillTextRecognizer` uses `VNRecognizeTextRequest` with accurate recognition and
language correction enabled. It collects the top candidate for each observation and joins lines with
newlines.

### Flow Prepared By This Slice

Future slices can connect:

1. camera/document scanning,
2. `VisionPurchaseBillTextRecognizer`,
3. `PurchaseBillDraftParser`,
4. owner review and save.

## Test Plan

- Unit tests:
  - No direct unit test is added for Apple Vision recognition because the framework behavior depends
    on image fixtures and OS-level OCR behavior. Future view models should test against the protocol
    using fake recognizers.

- Integration tests:
  - The unit/integration lane compiles and links the Vision OCR boundary.

- Acceptance tests:
  - Not required for this slice because there is no owner-facing UI yet.

## Acceptance Criteria

- The app has an injectable local OCR service boundary.
- The Vision implementation compiles in the app target.
- Recognized text output can feed the existing purchase bill draft parser.
- Tests pass locally and in CI.
