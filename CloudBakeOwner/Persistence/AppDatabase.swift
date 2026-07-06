import Foundation
import GRDB

final class AppDatabase {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    static func openConfigured() throws -> AppDatabase {
        if ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] == "1" {
            let database = try makeInMemory()
            try database.seedCustomerFixtureIfRequested()
            try database.seedOrderReminderFixtureIfRequested()
            return database
        }

        return try openDefault()
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

    private func seedCustomerFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let customer = Customer(
            id: "customer-ui-fixture-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: nil,
            dislikes: nil,
            allergies: "Nuts",
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(customer)
        try repository.save(
            CustomerImportantDate(
                id: "customer-ui-fixture-birthday",
                customerId: customer.id,
                label: "Birthday",
                date: Date(timeIntervalSince1970: 1_801_000_000),
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func seedOrderReminderFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_ORDER_REMINDER_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date()
        let dueAt = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: 1,
            to: timestamp
        ) ?? timestamp
        let order = Order(
            id: "order-ui-fixture-reminder",
            customerId: nil,
            cakeDesignId: nil,
            title: "Reminder Vanilla Birthday",
            customerName: "Amy",
            status: .confirmed,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: "Pink flowers",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(order)
    }

    private static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }
}
