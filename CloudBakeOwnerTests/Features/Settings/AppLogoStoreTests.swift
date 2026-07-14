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
        XCTAssertTrue(store.hasCustomLogo)

        try store.remove()

        XCTAssertNil(store.load())
        XCTAssertFalse(store.hasCustomLogo)
    }

    func testLogoOnlyInstallationCountsAsRestorableOwnerData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("Branding/custom-logo.jpg")
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try AppDatabase.makeInMemory()
        defer { try? database.close() }
        let logoStore = AppLogoStore(fileURL: fileURL)
        let state = OwnerInstallationState(database: database, logoStore: logoStore)

        XCTAssertFalse(try state.hasRestorableData())

        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        try logoStore.save(image)

        XCTAssertTrue(try state.hasRestorableData())
    }
}
