import Foundation
import GRDB

final class AppDatabase {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    static func openDefault() throws -> AppDatabase {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cloudBakeDirectory = applicationSupportURL.appendingPathComponent("CloudBakeOwner", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudBakeDirectory, withIntermediateDirectories: true)
        return try open(at: cloudBakeDirectory.appendingPathComponent("cloudbake-owner.sqlite"))
    }

    static func open(at databaseURL: URL) throws -> AppDatabase {
        let queue = try DatabaseQueue(path: databaseURL.path, configuration: configuration())
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        return AppDatabase(writer: queue)
    }

    static func makeInMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue(path: ":memory:", configuration: configuration())
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        return AppDatabase(writer: queue)
    }

    func makeHealthCheckRepository() -> any HealthCheckRepository {
        GRDBHealthCheckRepository(writer: writer)
    }

    func makeCoreDataRepository() -> GRDBCoreDataRepository {
        GRDBCoreDataRepository(writer: writer)
    }

    private static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }
}
