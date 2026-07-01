import XCTest
@testable import CloudBakeOwner

final class CoreDataRepositoryTests: XCTestCase {
    func testCoreEntitiesRoundTripThroughFreshDatabase() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamps = TestTimestamps(
            createdAt: Date(timeIntervalSince1970: 1_800_001_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_001_100)
        )

        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(inventoryItem)
        XCTAssertEqual(try repository.fetchInventoryItem(id: inventoryItem.id), inventoryItem)

        let recipe = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla sponge",
            notes: "Owner recipe book import target",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(recipe)
        XCTAssertEqual(try repository.fetchRecipe(id: recipe.id), recipe)

        let component = RecipeComponent(
            id: "component-sponge",
            recipeId: recipe.id,
            name: "Sponge",
            sortOrder: 1,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(component)
        XCTAssertEqual(try repository.fetchRecipeComponent(id: component.id), component)

        let ingredient = RecipeIngredient(
            id: "ingredient-flour",
            componentId: component.id,
            inventoryItemId: inventoryItem.id,
            quantity: 250,
            unit: .gram,
            note: "Sift before mixing",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(ingredient)
        XCTAssertEqual(try repository.fetchRecipeIngredient(id: ingredient.id), ingredient)

        let design = CakeDesign(
            id: "design-rose-garden",
            name: "Rose garden",
            notes: "Hand-piped flowers",
            photoReference: "photos/rose-garden.jpg",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(design)
        XCTAssertEqual(try repository.fetchCakeDesign(id: design.id), design)

        let customer = Customer(
            id: "customer-amy",
            displayName: "Amy",
            likes: "Vanilla, pink flowers",
            dislikes: "Too much fondant",
            allergies: "Nuts",
            notes: "Prefers less sweet frosting",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(customer)
        XCTAssertEqual(try repository.fetchCustomer(id: customer.id), customer)

        let order = Order(
            id: "order-rose-garden",
            customerId: customer.id,
            cakeDesignId: design.id,
            title: "Rose garden birthday cake",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(order)
        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)

        let transaction = InventoryTransaction(
            id: "transaction-flour-purchase",
            inventoryItemId: inventoryItem.id,
            kind: .purchase,
            quantity: 2_000,
            occurredAt: Date(timeIntervalSince1970: 1_800_002_000),
            note: "Restocked flour",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(transaction)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)

        let pricingRule = PricingRule(
            id: "pricing-base-cake",
            name: "Base cake",
            kind: .basePrice,
            amount: Decimal(7_550) / Decimal(100),
            currencyCode: "USD",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(pricingRule)
        XCTAssertEqual(try repository.fetchPricingRule(id: pricingRule.id), pricingRule)
    }

    func testInventoryItemsFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let sugar = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 250,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let butter = InventoryItem(
            id: "inventory-butter",
            name: "Butter",
            unit: .gram,
            currentQuantity: 600,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(sugar)
        try repository.save(butter)

        XCTAssertEqual(try repository.fetchInventoryItems(), [butter, sugar])
    }

    func testInventoryItemSaveUpdatesExistingItemWithSameId() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let original = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )
        let edited = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour fine",
            unit: .kilogram,
            currentQuantity: 1.25,
            minimumQuantity: 2,
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_800_020_200)
        )

        try repository.save(original)
        try repository.save(edited)

        XCTAssertEqual(try repository.fetchInventoryItem(id: "inventory-flour"), edited)
        XCTAssertEqual(try repository.fetchInventoryItems(), [edited])
    }

    func testInventoryItemsFetchExcludesArchivedItemsButDirectFetchStillFindsThem() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_020_000)
        let active = InventoryItem(
            id: "inventory-active-flour",
            name: "Active flour",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let archived = InventoryItem(
            id: "inventory-archived-flour",
            name: "Archived flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 500,
            createdAt: timestamp,
            updatedAt: timestamp,
            archivedAt: Date(timeIntervalSince1970: 1_800_020_100)
        )

        try repository.save(active)
        try repository.save(archived)

        XCTAssertEqual(try repository.fetchInventoryItems(), [active])
        XCTAssertEqual(try repository.fetchInventoryItem(id: archived.id), archived)
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [archived])
    }

    func testRestoredInventoryItemMovesBackToActiveFetch() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let archivedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let restoredAt = Date(timeIntervalSince1970: 1_800_020_200)
        let archived = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: archivedAt,
            archivedAt: archivedAt
        )
        let restored = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: restoredAt
        )

        try repository.save(archived)
        try repository.save(restored)

        XCTAssertEqual(try repository.fetchInventoryItems(), [restored])
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [])
    }

    func testInventoryAdjustmentStoresUpdatedQuantityAndTransaction() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let adjustedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: adjustedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-adjustment",
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: adjustedAt,
            note: "Restocked",
            createdAt: adjustedAt,
            updatedAt: adjustedAt
        )

        try repository.save(item)
        try repository.save(adjustedItem)
        try repository.save(transaction)

        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), adjustedItem)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }

    func testInventoryItemWithTransactionCanBeArchived() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let adjustedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let archivedAt = Date(timeIntervalSince1970: 1_800_020_200)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: adjustedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-adjustment",
            inventoryItemId: item.id,
            kind: .adjustment,
            quantity: 100,
            occurredAt: adjustedAt,
            note: nil,
            createdAt: adjustedAt,
            updatedAt: adjustedAt
        )
        let archivedItem = InventoryItem(
            id: item.id,
            name: item.name,
            unit: item.unit,
            currentQuantity: item.currentQuantity,
            minimumQuantity: item.minimumQuantity,
            createdAt: item.createdAt,
            updatedAt: archivedAt,
            archivedAt: archivedAt
        )

        try repository.save(item)
        try repository.save(transaction)
        try repository.save(archivedItem)

        XCTAssertEqual(try repository.fetchInventoryItems(), [])
        XCTAssertEqual(try repository.fetchArchivedInventoryItems(), [archivedItem])
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }

    func testInventoryConsumptionStoresUpdatedQuantityAndTransaction() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_020_000)
        let consumedAt = Date(timeIntervalSince1970: 1_800_020_100)
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 350,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let consumedItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: consumedAt
        )
        let transaction = InventoryTransaction(
            id: "transaction-flour-consumption",
            inventoryItemId: item.id,
            kind: .consumption,
            quantity: 100,
            occurredAt: consumedAt,
            note: "Vanilla sponge",
            createdAt: consumedAt,
            updatedAt: consumedAt
        )

        try repository.save(item)
        try repository.save(consumedItem)
        try repository.save(transaction)

        XCTAssertEqual(try repository.fetchInventoryItem(id: item.id), consumedItem)
        XCTAssertEqual(try repository.fetchInventoryTransaction(id: transaction.id), transaction)
    }
}

private struct TestTimestamps {
    let createdAt: Date
    let updatedAt: Date
}
