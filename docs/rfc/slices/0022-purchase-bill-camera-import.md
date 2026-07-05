# Slice RFC-0022: Purchase Bill Camera Import

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Let the owner scan a purchase bill with the iPhone camera and create editable inventory drafts from
the recognized bill text.

## Scope

- Open the camera from the purchase bill import flow when camera hardware is available.
- Capture a purchase bill photo.
- Run local Apple Vision OCR against the captured image.
- Parse recognized text through the baking catalog and purchase bill draft parser.
- Show editable draft inventory rows after OCR and parsing.
- Keep manual recognized text entry as a fallback for unclear photos or simulator testing.
- Add the camera usage privacy description.
- Add unit tests for OCR-to-draft success and OCR failure handling.
- Update README and wiki product documentation.

## Out Of Scope

- Photo library import.
- Multi-page bill capture.
- Cropping, perspective correction, or document-edge detection.
- Duplicate matching during draft save.
- Merging scanned drafts into existing inventory.
- Supplier, price, tax, or payment metadata extraction.

## Requirements

- Tapping Import Bill should offer camera capture on a physical device.
- The owner must be able to take a bill photo and receive editable inventory drafts.
- OCR and parsing must run locally on the device.
- The app must show a useful error when the bill photo cannot be read.
- Manual text entry must remain available as a fallback.
- Tests must cover OCR success and failure without requiring camera hardware.

## Design

`PurchaseBillImportView` opens a camera full-screen cover when the import flow appears on a device
with camera hardware. It also exposes a Take Bill Photo action for retakes.

`PurchaseBillCameraView` wraps `UIImagePickerController` for photo capture. When a photo is
captured, the view passes the `CGImage` to `InventoryListViewModel`.

`InventoryListViewModel.recognizePurchaseBillImage(_:recognizer:catalog:)` owns the OCR-to-draft
state transition. It runs `PurchaseBillTextRecognizing`, stores recognized text, creates drafts, and
clears stale drafts if OCR fails.

The implementation keeps a multiline text entry area in the import sheet so the owner can correct OCR text or
enter bill text manually when camera OCR is not suitable.

## Test Plan

- Unit tests:
  - Recognized image text creates purchase bill drafts.
  - OCR failure clears stale drafts and shows a manual-entry fallback error.

- Build validation:
  - Simulator build verifies SwiftUI/UIKit integration and Info.plist generation.

## Acceptance Criteria

- Import Bill opens camera capture on physical iPhone.
- Captured bill photos are read through local Vision OCR.
- Baking-related bill lines become editable draft inventory items.
- The owner can still manually edit recognized bill text before creating drafts.
- App declares camera usage permission.
