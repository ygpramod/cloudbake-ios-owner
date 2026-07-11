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
            try database.seedOrderCustomerLinkFixtureIfRequested()
            try database.seedCompletedOrderFixtureIfRequested()
            try database.seedOrderReminderFixtureIfRequested()
            try database.seedInventoryFixtureIfRequested()
            try database.seedCakeDesignFixtureIfRequested()
            try database.seedDesignGalleryFixtureIfRequested()
            try database.seedOrderPhotoFixtureIfRequested()
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

    private func seedInventoryFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_INVENTORY_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let expiresAt = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: 7,
            to: Date()
        ) ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
        let item = InventoryItem(
            id: "inventory-ui-fixture-cake-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(item)
        try repository.save(
            InventoryStockBatch(
                id: "inventory-batch-ui-fixture-cake-flour",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: expiresAt,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func seedOrderCustomerLinkFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_ORDER_CUSTOMER_LINK_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        try repository.save(
            Customer(
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
        )
        try repository.save(
            Order(
                id: "order-ui-fixture-customer-link",
                customerId: "customer-ui-fixture-amy",
                cakeDesignId: nil,
                title: "Vanilla Birthday",
                customerName: "Amy",
                status: .confirmed,
                dueAt: Date(timeIntervalSince1970: 1_800_140_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: "Pink flowers",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func seedCompletedOrderFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_COMPLETED_ORDER_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        try repository.save(
            Order(
                id: "order-ui-fixture-completed",
                customerId: nil,
                cakeDesignId: nil,
                title: "Completed Birthday",
                customerName: "Amy",
                status: .completed,
                dueAt: Date(timeIntervalSince1970: 1_800_140_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: "Boxed",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func seedCakeDesignFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        try repository.save(
            CakeDesign(
                id: "design-ui-fixture-floral",
                name: "Pink Floral Cake",
                notes: "Hand-piped buttercream flowers",
                photoReference: "photos/pink-floral.jpg",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }

    private func seedDesignGalleryFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_DESIGN_GALLERY_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        for (id, name) in [
            ("design-ui-gallery-first", "First Gallery Cake"),
            ("design-ui-gallery-second", "Second Gallery Cake")
        ] {
            try repository.save(
                CakeDesign(
                    id: id,
                    name: name,
                    notes: nil,
                    photoReference: nil,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
    }

    private func seedOrderPhotoFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let order = Order(
            id: "order-ui-fixture-photos",
            customerId: nil,
            cakeDesignId: nil,
            title: "Photo Vanilla Birthday",
            customerName: "Amy",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_140_000),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: "Pink flowers",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(order)
        try repository.save(
            OrderPhoto(
                id: "photo-ui-fixture-reference",
                orderId: order.id,
                kind: .customerReference,
                localPhotoPath: "OrderPhotos/order-ui-fixture-photos/photo-ui-fixture-reference.jpg",
                caption: "Customer sketch",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        try repository.save(
            OrderPhoto(
                id: "photo-ui-fixture-final",
                orderId: order.id,
                kind: .finalCake,
                localPhotoPath: "OrderPhotos/order-ui-fixture-photos/photo-ui-fixture-final.jpg",
                caption: "Finished cake",
                createdAt: timestamp.addingTimeInterval(60),
                updatedAt: timestamp.addingTimeInterval(60)
            )
        )
    }

    private static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }
}
