import Foundation
import GRDB

final class AppDatabase {
    private let writer: DatabaseQueue

    init(writer: DatabaseQueue) {
        self.writer = writer
    }

    static func openConfigured() throws -> AppDatabase {
        if ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] == "1" {
            let database = try makeInMemory()
            try database.seedCustomerFixtureIfRequested()
            try database.seedOrderCustomerLinkFixtureIfRequested()
            try database.seedCompletedOrderFixtureIfRequested()
            try database.seedOrderReminderFixtureIfRequested()
            try database.seedOrderStatusFailureFixtureIfRequested()
            try database.seedInventoryFixtureIfRequested()
            try database.seedLongInventoryFixtureIfRequested()
            try database.seedExpiredInventoryFixtureIfRequested()
            try database.seedProjectedDemandFixtureIfRequested()
            try database.seedCakeDesignFixtureIfRequested()
            try database.seedDesignGalleryFixtureIfRequested()
            try database.seedDesignScrollFixtureIfRequested()
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
        let databaseURL = cloudBakeDirectory.appendingPathComponent("cloudbake-owner.sqlite")
        try InterruptedRestoreRecovery.recoverIfNeeded(
            appStorageRoot: cloudBakeDirectory,
            databaseURL: databaseURL,
            activationRoot: applicationSupportURL.appendingPathComponent(
                InterruptedRestoreRecovery.directoryName,
                isDirectory: true
            )
        )
        return try open(at: databaseURL)
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

    func writeBackupSnapshot(to destinationURL: URL) throws {
        let destination = try DatabaseQueue(path: destinationURL.path)
        try writer.backup(to: destination)
    }

    func replaceContents(from sourceURL: URL) throws {
        let source = try DatabaseQueue(path: sourceURL.path, configuration: Self.configuration())
        try source.backup(to: writer)
        try source.close()
    }

    func hasOwnerData() throws -> Bool {
        try writer.read { db in
            let tables = [
                "inventory_items", "recipes", "cake_designs", "customers", "orders",
                "inventory_transactions", "pricing_rules"
            ]
            for table in tables where try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 > 0 {
                return true
            }
            return false
        }
    }

    func assetReferences() throws -> [String] {
        try writer.read { db in
            let designs = try String.fetchAll(
                db,
                sql: "SELECT photo_reference FROM cake_designs WHERE photo_reference IS NOT NULL"
            )
            let orders = try String.fetchAll(
                db,
                sql: "SELECT local_photo_path FROM order_photos"
            )
            return Array(Set(designs + orders)).sorted()
        }
    }

    func verifyIntegrity() throws {
        try LocalRestoreService.verifyIntegrity(of: writer)
    }

    func close() throws {
        try writer.close()
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

    private func seedLongInventoryFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_LONG_INVENTORY_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        for index in 1...8 {
            try repository.save(
                InventoryItem(
                    id: "inventory-ui-scroll-\(index)",
                    name: "Scroll item \(index.formatted(.number.precision(.integerLength(2))))",
                    unit: .each,
                    currentQuantity: Double(index),
                    minimumQuantity: 0,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
    }

    private func seedExpiredInventoryFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_EXPIRED_INVENTORY_FIXTURE"] == "1" else {
            return
        }
        let repository = makeCoreDataRepository()
        let now = Date()
        let item = InventoryItem(
            id: "inventory-ui-expired-cream",
            name: "Expired cream",
            unit: .milliliter,
            currentQuantity: 200,
            minimumQuantity: 50,
            createdAt: now,
            updatedAt: now
        )
        try repository.save(item)
        try repository.save(
            InventoryStockBatch(
                id: "inventory-ui-expired-cream-batch",
                inventoryItemId: item.id,
                remainingQuantity: 75,
                expiresAt: now.addingTimeInterval(-86_400),
                createdAt: now,
                updatedAt: now
            )
        )
        try repository.save(
            InventoryStockBatch(
                id: "inventory-ui-usable-cream-batch",
                inventoryItemId: item.id,
                remainingQuantity: 125,
                expiresAt: now.addingTimeInterval(86_400),
                createdAt: now,
                updatedAt: now
            )
        )
    }

    private func seedProjectedDemandFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_PROJECTED_DEMAND_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date()
        let flour = InventoryItem(
            id: "inventory-ui-projected-flour",
            name: "Projected cake flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(flour)
        try repository.save(
            InventoryStockBatch(
                id: "inventory-ui-projected-flour-batch",
                inventoryItemId: flour.id,
                remainingQuantity: 200,
                expiresAt: timestamp.addingTimeInterval(86_400),
                amount: 100,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        try repository.save(
            InventoryStockBatch(
                id: "inventory-ui-projected-flour-missing-price-batch",
                inventoryItemId: flour.id,
                remainingQuantity: 300,
                expiresAt: timestamp.addingTimeInterval(172_800),
                amount: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        let recipe = Recipe(
            id: "recipe-ui-projected-cake",
            name: "Projected Cake",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let component = RecipeComponent(
            id: "component-ui-projected-cake",
            recipeId: recipe.id,
            name: "Cake",
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(
            RecipeIngredient(
                id: "ingredient-ui-projected-flour",
                componentId: component.id,
                inventoryItemId: flour.id,
                quantity: 300,
                unit: .gram,
                note: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        for index in 1...2 {
            try repository.save(
                Order(
                    id: "order-ui-projected-\(index)",
                    customerId: nil,
                    cakeDesignId: nil,
                    recipeId: recipe.id,
                    title: "Projected Cake \(index)",
                    customerName: "Amy",
                    status: .confirmed,
                    dueAt: timestamp.addingTimeInterval(Double(index) * 86_400),
                    fulfillmentType: .pickup,
                    deliveryAddress: nil,
                    cakeNotes: nil,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
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

    private func seedOrderStatusFailureFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_ORDER_STATUS_FAILURE_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let recipe = Recipe(
            id: "recipe-ui-fixture-no-ingredients",
            name: "Unfinished recipe",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(recipe)
        try repository.save(
            Order(
                id: "order-ui-fixture-status-failure",
                customerId: nil,
                cakeDesignId: nil,
                recipeId: recipe.id,
                title: "Status failure cake",
                customerName: "Amy",
                status: .confirmed,
                dueAt: Date(timeIntervalSince1970: 1_800_140_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
        try repository.save(
            Order(
                id: "order-ui-fixture-draft-status",
                customerId: nil,
                cakeDesignId: nil,
                recipeId: recipe.id,
                title: "Draft status cake",
                customerName: "Amy",
                status: .draft,
                dueAt: Date(timeIntervalSince1970: 1_800_150_000),
                fulfillmentType: .pickup,
                deliveryAddress: nil,
                cakeNotes: nil,
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
        let photoReference = "photos/pink-floral.jpg"
        try seedPhotoFixture(at: photoReference)
        try repository.save(
            CakeDesign(
                id: "design-ui-fixture-floral",
                name: "Pink Floral Cake",
                notes: "Hand-piped buttercream flowers",
                photoReference: photoReference,
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
                    tags: ["Floral"],
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
    }

    private func seedDesignScrollFixtureIfRequested() throws {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_SEED_DESIGN_SCROLL_FIXTURE"] == "1" else {
            return
        }

        let repository = makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        for index in 0..<8 {
            try repository.save(
                CakeDesign(
                    id: "design-ui-scroll-\(index)",
                    name: "Scroll Design \(index)",
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
        try seedPhotoFixture(
            at: "OrderPhotos/order-ui-fixture-photos/photo-ui-fixture-reference.jpg"
        )
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
            CakeDesign(
                id: "design-ui-fixture-reference",
                name: "Customer sketch",
                notes: nil,
                photoReference: "OrderPhotos/order-ui-fixture-photos/photo-ui-fixture-reference.jpg",
                sourceKind: .customerReference,
                originatingOrderPhotoId: "photo-ui-fixture-reference",
                originatingOrderId: order.id,
                tags: ["Wedding"],
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

    private func seedPhotoFixture(at relativePath: String) throws {
        let fileStore = LocalOrderPhotoFileStore()
        let fileURL = fileStore.fileURL(for: relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let onePixelPNG = Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try onePixelPNG.write(to: fileURL, options: .atomic)
    }

    private static func configuration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }
}
