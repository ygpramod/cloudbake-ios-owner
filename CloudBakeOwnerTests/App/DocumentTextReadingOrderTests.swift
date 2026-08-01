import CoreGraphics
import XCTest

@testable import CloudBakeOwner

final class DocumentTextReadingOrderTests: XCTestCase {
    func testSortsReceiptRegionsFromTopToBottom() {
        let regions = [
            region("Sugar", x: 0.08, y: 0.62),
            region("2.50", x: 0.76, y: 0.78),
            region("Flour", x: 0.08, y: 0.78),
            region("1 kg", x: 0.48, y: 0.62),
        ]

        XCTAssertEqual(
            DocumentTextReadingOrder.text(from: regions),
            "Flour 2.50\nSugar 1 kg"
        )
    }

    func testGroupsSlightlyMisalignedBoxesOnTheSameReceiptLine() {
        let regions = [
            region("800", x: 0.52, y: 0.79, height: 0.045),
            region("grams", x: 0.68, y: 0.785, height: 0.05),
            region("Flour", x: 0.08, y: 0.80, height: 0.055),
        ]

        XCTAssertEqual(
            DocumentTextReadingOrder.text(from: regions),
            "Flour 800 grams"
        )
    }

    func testIgnoresEmptyRecognitionRegions() {
        let regions = [
            region("  Flour ", x: 0.08, y: 0.78),
            region("  ", x: 0.40, y: 0.78),
        ]

        XCTAssertEqual(DocumentTextReadingOrder.text(from: regions), "Flour")
    }

    private func region(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 0.14,
        height: CGFloat = 0.05
    ) -> DocumentTextRegion {
        DocumentTextRegion(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height)
        )
    }
}
