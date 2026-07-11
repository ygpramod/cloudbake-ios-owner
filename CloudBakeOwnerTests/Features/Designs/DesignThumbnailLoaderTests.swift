import XCTest
import UIKit
@testable import CloudBakeOwner

final class DesignThumbnailLoaderTests: XCTestCase {
    func testThumbnailPipelineLoadsOneHundredLargeImagesWithinBudget() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_600, height: 1_600)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_600, height: 1_600))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let urls = try (0..<100).map { index in
            let url = directory.appendingPathComponent("design-\(index).jpg")
            try data.write(to: url)
            return url
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        let loadedCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for url in urls {
                group.addTask {
                    await DesignThumbnailLoader.shared.image(
                        for: .legacyFile(url),
                        maximumPixelSize: 300
                    ) != nil
                }
            }
            var count = 0
            for await didLoad in group where didLoad { count += 1 }
            return count
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt

        XCTAssertEqual(loadedCount, urls.count)
        XCTAssertLessThan(elapsed, 5, "100-thumbnail decode exceeded five seconds")
    }
}
