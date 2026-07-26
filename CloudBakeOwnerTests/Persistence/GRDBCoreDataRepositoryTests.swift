import GRDB
import XCTest
@testable import CloudBakeOwner

final class GRDBCoreDataRepositoryTests: XCTestCase {
    func testCoreEntitiesRoundTripThroughFreshDatabase() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamps = TestTimestamps(
            createdAt: Date(timeIntervalSince1970: 1_800_001_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_001_100)
        )

        let inventoryItem = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            aliases: ["Maida", "Plain flour"],
            type: .perishable,
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
        XCTAssertEqual(try repository.fetchRecipeComponents(recipeId: recipe.id), [component])

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
        XCTAssertEqual(try repository.fetchRecipeIngredients(componentId: component.id), [ingredient])

        let design = CakeDesign(
            id: "design-rose-garden",
            name: "Rose garden",
            notes: "Hand-piped flowers",
            photoReference: "photos/rose-garden.jpg",
            sourceKind: .internetInspiration,
            sourceName: "Cake Artist",
            sourceURL: "https://example.com/rose-garden",
            tags: ["Floral", "Birthday"],
            isFavorite: true,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(design)
        XCTAssertEqual(try repository.fetchCakeDesign(id: design.id), design)
        XCTAssertEqual(try repository.fetchCakeDesigns(), [design])
        XCTAssertEqual(try repository.fetchCakeDesigns(sourceKind: .internetInspiration), [design])
        XCTAssertTrue(try repository.fetchCakeDesigns(sourceKind: .ownerMade).isEmpty)

        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Vanilla, pink flowers",
            dislikes: "Too much fondant",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Prefers less sweet frosting",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(customer)
        XCTAssertEqual(try repository.fetchCustomer(id: customer.id), customer)

        let importantDate = CustomerImportantDate(
            id: "customer-date-birthday",
            customerId: customer.id,
            label: "Birthday",
            date: Date(timeIntervalSince1970: 1_800_030_000),
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(importantDate)
        XCTAssertEqual(try repository.fetchCustomerImportantDates(customerId: customer.id), [importantDate])

        let order = Order(
            id: "order-rose-garden",
            customerId: customer.id,
            cakeDesignId: design.id,
            recipeId: recipe.id,
            title: "Rose garden birthday cake",
            customerName: customer.name,
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_050_000),
            fulfillmentType: .delivery,
            deliveryAddress: "10 Cake Street",
            cakeNotes: "Vanilla sponge with pink flowers",
            cakeMessage: "Happy Birthday Amy",
            quotedPrice: Decimal(string: "180.75"),
            depositPaid: Decimal(string: "50.25"),
            paymentNotes: "Deposit paid by bank transfer",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(order)
        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)
        XCTAssertEqual(try repository.fetchOrders(), [order])

        let checklistItem = OrderChecklistItem(
            id: "checklist-crumb-coat",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(checklistItem)
        XCTAssertEqual(try repository.fetchOrderChecklistItems(orderId: order.id), [checklistItem])

        let orderPhoto = OrderPhoto(
            id: "photo-reference",
            orderId: order.id,
            kind: .customerReference,
            localPhotoPath: "OrderPhotos/order-rose-garden/reference.jpg",
            caption: "Customer sketch",
            tags: ["Floral"],
            isFavorite: true,
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(orderPhoto)
        XCTAssertEqual(try repository.fetchOrderPhotos(orderId: order.id), [orderPhoto])

        let promotedDesign = CakeDesign(
            id: design.id,
            name: design.name,
            notes: design.notes,
            photoReference: design.photoReference,
            sourceKind: .ownerMade,
            originatingOrderPhotoId: orderPhoto.id,
            originatingOrderId: order.id,
            isPortfolioPublished: true,
            createdAt: design.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(promotedDesign)
        XCTAssertEqual(try repository.fetchCakeDesign(id: design.id), promotedDesign)

        try repository.deleteOrderPhoto(id: orderPhoto.id)
        let designAfterPhotoDeletion = try XCTUnwrap(repository.fetchCakeDesign(id: design.id))
        XCTAssertNil(designAfterPhotoDeletion.originatingOrderPhotoId)
        XCTAssertEqual(designAfterPhotoDeletion.originatingOrderId, order.id)

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

        let stockBatch = InventoryStockBatch(
            id: "batch-flour-purchase",
            inventoryItemId: inventoryItem.id,
            remainingQuantity: 750,
            expiresAt: Date(timeIntervalSince1970: 1_800_086_400),
            amount: Decimal(string: "2.50"),
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        try repository.save(stockBatch)
        XCTAssertEqual(try repository.fetchInventoryStockBatches(inventoryItemId: inventoryItem.id), [stockBatch])

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

    func testRecipesFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let vanilla = Recipe(
            id: "recipe-vanilla-sponge",
            name: "Vanilla Sponge",
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let chocolate = Recipe(
            id: "recipe-chocolate-truffle",
            name: "Chocolate Truffle",
            notes: "Book page 18",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(vanilla)
        try repository.save(chocolate)

        XCTAssertEqual(try repository.fetchRecipes(), [chocolate, vanilla])
    }

    func testCustomersFetchInNameOrder() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_010_000)
        let zoe = Customer(
            id: "customer-zoe",
            name: "Zoe",
            phone: "5550102",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let amy = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(zoe)
        try repository.save(amy)

        XCTAssertEqual(try repository.fetchCustomers(), [amy, zoe])
    }

    func testOrderPagesUseStableBoundedKeysetPagination() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let orders = [
            pagedOrder(id: "active-a", status: .confirmed, dueAt: start),
            pagedOrder(id: "active-b", status: .ready, dueAt: start),
            pagedOrder(
                id: "active-c",
                status: .inProgress,
                dueAt: start.addingTimeInterval(60)
            ),
            pagedOrder(
                id: "completed-a",
                status: .completed,
                dueAt: start.addingTimeInterval(120)
            ),
            pagedOrder(
                id: "cancelled-a",
                status: .cancelled,
                dueAt: start.addingTimeInterval(180)
            )
        ]
        try orders.forEach(repository.save)

        let first = try repository.fetchOrderPage(
            query: .active(dueAtRange: nil),
            after: nil,
            limit: 2
        )
        let second = try repository.fetchOrderPage(
            query: .active(dueAtRange: nil),
            after: try XCTUnwrap(first.nextCursor),
            limit: 2
        )
        let completed = try repository.fetchOrderPage(
            query: .completed,
            after: nil,
            limit: 2
        )

        XCTAssertEqual(first.orders.map(\.id), ["active-a", "active-b"])
        XCTAssertEqual(second.orders.map(\.id), ["active-c"])
        XCTAssertNil(second.nextCursor)
        XCTAssertEqual(
            completed.orders.map(\.id),
            ["cancelled-a", "completed-a"]
        )
    }

    func testOrderPagesApplyUpcomingCustomerAndPaymentFiltersInSQL() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let customerId = "customer-amy"
        try repository.save(
            Customer(
                id: customerId,
                name: "Amy",
                phone: "5550101",
                email: nil,
                address: nil,
                likes: nil,
                dislikes: nil,
                allergies: nil,
                dietaryRestrictions: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        try repository.save(
            Customer(
                id: "customer-other",
                name: "Other",
                phone: "5550102",
                email: nil,
                address: nil,
                likes: nil,
                dislikes: nil,
                allergies: nil,
                dietaryRestrictions: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        let orders = [
            pagedOrder(
                id: "upcoming",
                customerId: customerId,
                status: .confirmed,
                dueAt: now.addingTimeInterval(60)
            ),
            pagedOrder(
                id: "outside-window",
                customerId: "customer-other",
                status: .ready,
                dueAt: now.addingTimeInterval(3_600)
            ),
            pagedOrder(
                id: "payment-pending",
                customerId: customerId,
                status: .completed,
                dueAt: now.addingTimeInterval(-60),
                quotedPrice: 100,
                depositPaid: 25
            ),
            pagedOrder(
                id: "payment-paid",
                customerId: customerId,
                status: .completed,
                dueAt: now.addingTimeInterval(-120),
                quotedPrice: 100,
                depositPaid: 100
            )
        ]
        try orders.forEach(repository.save)

        let upcoming = try repository.fetchOrderPage(
            query: .upcoming(
                from: now,
                through: now.addingTimeInterval(300)
            ),
            after: nil,
            limit: 25
        )
        let customer = try repository.fetchOrderPage(
            query: .customer(id: customerId),
            after: nil,
            limit: 25
        )
        let paymentPending = try repository.fetchOrderPage(
            query: .paymentPending(asOf: now),
            after: nil,
            limit: 25
        )
        let upcomingCount = try repository.fetchOrderCount(
            query: .upcoming(
                from: now,
                through: now.addingTimeInterval(300)
            )
        )
        let customerCount = try repository.fetchOrderCount(
            query: .customer(id: customerId)
        )
        let paymentPendingCount = try repository.fetchOrderCount(
            query: .paymentPending(asOf: now)
        )

        XCTAssertEqual(upcoming.orders.map(\.id), ["upcoming"])
        XCTAssertEqual(
            customer.orders.map(\.id),
            ["payment-paid", "payment-pending", "upcoming"]
        )
        XCTAssertEqual(paymentPending.orders.map(\.id), ["payment-pending"])
        XCTAssertEqual(upcomingCount, 1)
        XCTAssertEqual(customerCount, 3)
        XCTAssertEqual(paymentPendingCount, 1)
    }

    func testOrderPagesRejectInvalidBounds() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        XCTAssertThrowsError(
            try repository.fetchOrderPage(
                query: .active(dueAtRange: nil),
                after: nil,
                limit: 0
            )
        ) { error in
            XCTAssertEqual(error as? OrderPageQueryError, .invalidLimit)
        }
        XCTAssertThrowsError(
            try repository.fetchOrderPage(
                query: .upcoming(
                    from: Date(timeIntervalSince1970: 2),
                    through: Date(timeIntervalSince1970: 1)
                ),
                after: nil,
                limit: 25
            )
        ) { error in
            XCTAssertEqual(error as? OrderPageQueryError, .invalidDateRange)
        }
        XCTAssertThrowsError(
            try repository.fetchOrderCount(
                query: .upcoming(
                    from: Date(timeIntervalSince1970: 2),
                    through: Date(timeIntervalSince1970: 1)
                )
            )
        ) { error in
            XCTAssertEqual(error as? OrderPageQueryError, .invalidDateRange)
        }
    }

    private func pagedOrder(
        id: String,
        customerId: String? = nil,
        status: OrderStatus,
        dueAt: Date,
        quotedPrice: Decimal? = nil,
        depositPaid: Decimal? = nil
    ) -> Order {
        Order(
            id: id,
            customerId: customerId,
            cakeDesignId: nil,
            title: id,
            customerName: "Customer",
            status: status,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            quotedPrice: quotedPrice,
            depositPaid: depositPaid,
            createdAt: dueAt,
            updatedAt: dueAt
        )
    }

}
