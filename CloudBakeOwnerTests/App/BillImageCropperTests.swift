import UIKit
import XCTest

@testable import CloudBakeOwner

final class BillImageCropperTests: XCTestCase {
    func testCropUsesNormalizedImageCoordinates() throws {
        let image = solidImage(size: CGSize(width: 200, height: 100))

        let cropped = try XCTUnwrap(
            BillImageCropper.crop(image, to: CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6))
        )

        XCTAssertEqual(cropped.cgImage?.width, 100)
        XCTAssertEqual(cropped.cgImage?.height, 60)
    }

    func testCropClampsSelectionToImageBounds() throws {
        let image = solidImage(size: CGSize(width: 200, height: 100))

        let cropped = try XCTUnwrap(
            BillImageCropper.crop(image, to: CGRect(x: -0.1, y: 0.5, width: 0.4, height: 0.8))
        )

        XCTAssertEqual(cropped.cgImage?.width, 60)
        XCTAssertEqual(cropped.cgImage?.height, 50)
    }

    private func solidImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
