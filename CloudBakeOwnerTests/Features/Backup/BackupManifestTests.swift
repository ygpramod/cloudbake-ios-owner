import Foundation
import XCTest
@testable import CloudBakeOwner

final class BackupManifestTests: XCTestCase {
    func testManifestSortsAssetsAndCalculatesPayloadSize() throws {
        let manifest = makeManifest(
            assets: [
                makeAsset(path: "OrderPhotos/z.jpg", bytes: 7),
                makeAsset(path: "Branding/custom-logo.jpg", bytes: 5)
            ]
        )

        XCTAssertEqual(
            manifest.assets.map(\.originalRelativePath),
            ["Branding/custom-logo.jpg", "OrderPhotos/z.jpg"]
        )
        XCTAssertEqual(manifest.totalByteCount, 22)

        let data = try JSONEncoder().encode(manifest)
        XCTAssertEqual(try JSONDecoder().decode(BackupManifest.self, from: data), manifest)
    }

    func testCompatibilityRejectsUnknownFormatAndOlderApp() {
        XCTAssertEqual(makeManifest(formatVersion: 2).compatibility(currentAppVersion: "1.0"),
                       .unsupportedFormat(found: 2, supported: 1))
        XCTAssertEqual(makeManifest(minimumAppVersion: "2.1").compatibility(currentAppVersion: "2.0.9"),
                       .appUpdateRequired(minimumVersion: "2.1"))
        XCTAssertEqual(makeManifest(minimumAppVersion: "2.1").compatibility(currentAppVersion: "2.1"),
                       .compatible)
    }

    func testSafeRelativePathRejectsTraversalAndAbsolutePaths() {
        XCTAssertTrue(BackupPath.isSafeRelativePath("OrderPhotos/order/photo.jpg"))
        XCTAssertFalse(BackupPath.isSafeRelativePath("../photo.jpg"))
        XCTAssertFalse(BackupPath.isSafeRelativePath("OrderPhotos/../photo.jpg"))
        XCTAssertFalse(BackupPath.isSafeRelativePath("/private/photo.jpg"))
        XCTAssertFalse(BackupPath.isSafeRelativePath(""))
    }

    func testSafeIdentifierAllowsOpaqueIDsOnly() {
        XCTAssertTrue(BackupPath.isSafeIdentifier("6ea15e35-4c28-43c9-a91e-8dfcf65dc296"))
        XCTAssertFalse(BackupPath.isSafeIdentifier("customer backup"))
        XCTAssertFalse(BackupPath.isSafeIdentifier("../backup"))
        XCTAssertFalse(BackupPath.isSafeIdentifier(".hidden"))
    }

    func testChecksumMatchesKnownSHA256() {
        XCTAssertEqual(
            BackupChecksum.sha256(of: Data("CloudBake".utf8)),
            "2d8be3b9b0266932bd8c0e843b89a3467235149825968fff61954b23d3093186"
        )
    }

    private func makeManifest(
        formatVersion: Int = BackupManifest.currentFormatVersion,
        minimumAppVersion: String = "1.0",
        assets: [BackupAssetDescriptor] = []
    ) -> BackupManifest {
        BackupManifest(
            formatVersion: formatVersion,
            databaseSchemaVersion: "0027_add_order_ingredient_costs",
            minimumCompatibleAppVersion: minimumAppVersion,
            generationID: "generation-1",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            database: BackupFileDescriptor(relativePath: "database.sqlite", byteCount: 10, sha256: "db"),
            assets: assets
        )
    }

    private func makeAsset(path: String, bytes: Int64) -> BackupAssetDescriptor {
        BackupAssetDescriptor(
            originalRelativePath: path,
            file: BackupFileDescriptor(relativePath: "Assets/\(path)", byteCount: bytes, sha256: path)
        )
    }
}
