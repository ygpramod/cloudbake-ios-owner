import XCTest
@testable import CloudBakeOwner

final class AppDatabaseTests: XCTestCase {
    func testInMemoryDatabaseRunsMigrationsFromScratch() throws {
        let database = try AppDatabase.makeInMemory()
        let repository = database.makeHealthCheckRepository()
        let entry = HealthCheckEntry(
            id: "migration-smoke-test",
            note: "Database is usable after migrations",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try repository.save(entry)

        XCTAssertEqual(try repository.fetch(id: entry.id), entry)
    }

    func testFileDatabaseRunsMigrationsFromScratch() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let databaseURL = temporaryDirectory.appendingPathComponent("cloudbake-owner.sqlite")
        let database = try AppDatabase.open(at: databaseURL)
        let repository = database.makeHealthCheckRepository()
        let entry = HealthCheckEntry(
            id: "file-database-smoke-test",
            note: "File database is usable after migrations",
            createdAt: Date(timeIntervalSince1970: 1_800_000_100)
        )

        try repository.save(entry)

        XCTAssertEqual(try repository.fetch(id: entry.id), entry)
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
    }
}
