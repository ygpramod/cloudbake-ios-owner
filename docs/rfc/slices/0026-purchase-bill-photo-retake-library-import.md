# Slice RFC-0026: Purchase Bill Photo Retake And Library Import

## Status

Implemented

## Parent RFC

- `requirements.md`

## Related ADRs

- `docs/adr/0001-owner-app-swiftui.md`
- `docs/adr/0007-testing-strategy.md`

## Goal

Make purchase bill scanning more forgiving by letting the owner retake a bill photo or import an
existing bill photo from the photo library.

## Scope

- Keep camera capture available from the purchase bill import flow.
- Change the camera action to a retake action after a bill photo is selected.
- Allow selecting a bill image from the iOS photo library.
- Show a preview of the selected bill image in the import flow.
- Run the same local Apple Vision OCR and draft parser path for camera and library images.
- Add the photo library usage privacy description.
- Update acceptance coverage and product documentation.

## Out Of Scope

- Multi-page bill capture.
- Cropping, perspective correction, or document-edge detection.
- Manual OCR region selection.
- Saving purchase bill photos as business records.
- Supplier, price, tax, or payment metadata extraction.

## Requirements

- Import Bill must still offer camera capture when camera hardware is available.
- After a camera or library image is selected, the owner must see the selected bill preview.
- After an image is selected, the owner must be able to retake the bill photo.
- The owner must be able to choose an existing bill image from the photo library.
- Camera and library images must use the same local OCR-to-draft behavior.
- Manual recognized text entry must remain available as a fallback.

## Design

`PurchaseBillImportView` owns local photo selection state:

- selected bill preview image,
- camera presentation state,
- selected `PhotosPickerItem`.

Camera capture still uses `PurchaseBillCameraView`, which wraps `UIImagePickerController`.

Photo library import uses SwiftUI `PhotosPicker`, restricted to images. Once image data is loaded,
the view stores a preview image and sends the image through
`InventoryListViewModel.recognizePurchaseBillImage(_:recognizer:catalog:)`.

The camera button label changes from `Take Bill Photo` to `Retake Bill Photo` once an image has
been selected. Retaking a photo replaces the preview and reruns OCR.

## Tests

Acceptance coverage verifies that the purchase bill import flow exposes:

- camera capture,
- photo library import,
- manual recognized text entry,
- draft creation.

Existing view model tests continue to cover OCR success and failure independent of camera or photo
library hardware.

## Documentation

Updated:

- `README.md`
- `docs/rfc/slices/0022-purchase-bill-camera-import.md`
- `wiki/Current-App-Capabilities.md`
- `wiki/Inventory-Guide.md`
- `wiki/Owner-Workflows.md`

## Acceptance

- Owner can scan a bill using the camera.
- Owner can retake the bill photo from the import flow.
- Owner can import a bill image from the photo library.
- Selected bill images are previewed before saving drafts.
- Draft creation behavior remains local to the device.
