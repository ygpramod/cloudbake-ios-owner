import UIKit
import XCTest
@testable import CloudBakeOwner

final class AppLogoStoreTests: XCTestCase {
    func testSaveLoadAndRemoveSelectedImage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("logo.jpg")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppLogoStore(fileURL: fileURL)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }

        try store.save(image)

        XCTAssertNotNil(store.load())

        try store.remove()

        XCTAssertNil(store.load())
    }
}
