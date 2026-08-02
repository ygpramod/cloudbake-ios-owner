import GRDB
import XCTest

@testable import CloudBakeOwner

final class GRDBCoreDataRepositoryTests: XCTestCase {
    func testOrderCakeRequirementChoicesAreCaseInsensitivelyReusable() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let firstDate = Date(timeIntervalSince1970: 1_800_001_000)
        let secondDate = firstDate.addingTimeInterval(60)

        try repository.saveOrderCakeRequirementChoices(
            [(.spongeFlavour, "Pandan"), (.shape, "Hexagon")],
            at: firstDate
        )
        try repository.saveOrderCakeRequirementChoices(
            [(.spongeFlavour, "pandan")],
            at: secondDate
        )

        XCTAssertEqual(
            try repository.fetchOrderCakeRequirementChoices(field: .spongeFlavour),
            ["pandan"]
        )
        XCTAssertEqual(
            try repository.fetchOrderCakeRequirementChoices(field: .shape),
            ["Hexagon"]
        )
    }

    func testOrderTemplateRoundTripsAndDeletesChildren() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_001_000)
        let inventoryItem = makeInventoryItem(id: "template-inventory", name: "Berries")
        try repository.save(inventoryItem)
        let template = OrderTemplate(
            id: "template-birthday",
            name: "Birthday Standard",
            cakeTitle: "Vanilla Birthday",
            cakeDesignId: nil,
            recipeId: nil,
            recipeScaleMultiplier: 1,
            fulfillmentType: .pickup,
            cakeNotes: "Pink flowers",
            cakeMessage: "Happy Birthday",
            cakeSpecification: OrderCakeSpecification(
                occasion: "Birthday",
                servings: 28,
                size: "8 inch",
                weightKilograms: 2,
                shape: "Circle",
                tiers: "2",
                spongeFlavour: "Chocolate",
                filling: "Chocolate ganache",
                frosting: "Fondant",
                colourPalette: "Pink and gold",
                theme: "Floral",
                topperRequirements: "Name topper",
                candlesAndAccessories: "None",
                packaging: "Standard Box"
            ),
            reminderConfiguration: try OrderReminderConfiguration(
                mode: .custom,
                dayOffsets: [5, 1],
                includesDueTime: false
            ),
            extraIngredients: [
                OrderTemplateExtraIngredient(
                    id: "template-extra",
                    inventoryItemId: inventoryItem.id,
                    quantity: 100,
                    unit: .gram,
                    note: "Decoration",
                    sortOrder: 0
                )
            ],
            checklistItems: [
                OrderTemplateChecklistItem(
                    id: "template-checklist",
                    title: "Add topper",
                    sortOrder: 0
                )
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.save(template)

        XCTAssertEqual(
            try repository.fetchOrderTemplates().first { $0.id == template.id },
            template
        )

        try repository.deleteOrderTemplate(id: template.id)

        XCTAssertFalse(try repository.fetchOrderTemplates().contains { $0.id == template.id })
    }

    func testOrderTemplateForeignKeysClearReusableLinksAndProtectIngredients() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_001_000)
        let recipe = makeRecipe(id: "template-recipe", name: "Vanilla")
        let design = makeCakeDesign(id: "template-design", name: "Florals")
        let inventoryItem = makeInventoryItem(id: "template-ingredient", name: "Berries")
        try repository.save(recipe)
        try repository.save(design)
        try repository.save(inventoryItem)
        let template = OrderTemplate(
            id: "template-foreign-keys",
            name: "Reusable Links",
            cakeTitle: "Vanilla Floral",
            cakeDesignId: design.id,
            recipeId: recipe.id,
            recipeScaleMultiplier: 1,
            fulfillmentType: .pickup,
            cakeNotes: nil,
            cakeMessage: nil,
            reminderConfiguration: .initialDefault,
            extraIngredients: [
                OrderTemplateExtraIngredient(
                    id: "template-protected-extra",
                    inventoryItemId: inventoryItem.id,
                    quantity: 50,
                    unit: .gram,
                    note: nil,
                    sortOrder: 0
                )
            ],
            checklistItems: [],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(template)

        try queue.write { db in
            try db.execute(sql: "DELETE FROM recipes WHERE id = ?", arguments: [recipe.id])
            try db.execute(sql: "DELETE FROM cake_designs WHERE id = ?", arguments: [design.id])
        }

        let unlinkedTemplate = try XCTUnwrap(
            repository.fetchOrderTemplates().first { $0.id == template.id }
        )
        XCTAssertNil(unlinkedTemplate.recipeId)
        XCTAssertNil(unlinkedTemplate.cakeDesignId)
        XCTAssertEqual(unlinkedTemplate.extraIngredients, template.extraIngredients)
        XCTAssertThrowsError(
            try queue.write { db in
                try db.execute(
                    sql: "DELETE FROM inventory_items WHERE id = ?",
                    arguments: [inventoryItem.id]
                )
            }
        )
        XCTAssertNotNil(try repository.fetchInventoryItem(id: inventoryItem.id))
    }

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
            cakeSpecification: OrderCakeSpecification(
                occasion: "Birthday",
                servings: 28,
                size: "8 inch",
                weightKilograms: 2,
                shape: "Circle",
                tiers: "2",
                spongeFlavour: "Vanilla",
                filling: "Strawberry compote",
                frosting: "Buttercream",
                colourPalette: "Pink",
                theme: "Rose garden",
                topperRequirements: "Happy Birthday topper",
                candlesAndAccessories: "Gold candles",
                packaging: "Tall Box"
            ),
            quotedPrice: Decimal(string: "180.75"),
            depositPaid: Decimal(string: "50.25"),
            paymentNotes: "Deposit paid by bank transfer",
            createdAt: timestamps.createdAt,
            updatedAt: timestamps.updatedAt
        )
        let persistedOrder = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            recipeId: order.recipeId,
            title: order.title,
            customerName: order.customerName,
            status: order.status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            cakeMessage: order.cakeMessage,
            cakeSpecification: order.cakeSpecification,
            quotedPrice: order.quotedPrice,
            depositPaid: nil,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: order.updatedAt
        )
        try repository.saveOrder(
            persistedOrder,
            replacingExtraIngredients: [],
            reminderConfiguration: .initialDefault,
            openingPayment: NewPaymentReceipt(
                amount: try XCTUnwrap(order.depositPaid),
                receivedAt: timestamps.updatedAt,
                note: order.paymentNotes,
                createdAt: timestamps.updatedAt
            ),
            allowInventoryShortage: false
        )
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
            ),
        ]
        for order in orders {
            try repository.save(orderWithoutRecordedPayment(order))
            if let amount = order.depositPaid, amount > 0 {
                _ = try repository.recordPayment(
                    orderId: order.id,
                    amount: amount,
                    receivedAt: order.updatedAt,
                    note: nil,
                    createdAt: order.updatedAt
                )
            }
        }

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
            ),
        ]
        for order in orders {
            try repository.save(orderWithoutRecordedPayment(order))
            if let amount = order.depositPaid, amount > 0 {
                _ = try repository.recordPayment(
                    orderId: order.id,
                    amount: amount,
                    receivedAt: now,
                    note: nil,
                    createdAt: now
                )
            }
        }

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

    func testTemplateSourceOrderSearchFindsMatchesBeyondFirstPage() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<30 {
            let id = index == 0 ? "needle-order" : "order-\(index)"
            try repository.save(
                pagedOrder(
                    id: id,
                    status: .confirmed,
                    dueAt: timestamp.addingTimeInterval(TimeInterval(index * 60))
                )
            )
        }

        let firstPage = try repository.fetchOrderPage(
            query: .all(searchText: ""),
            after: nil,
            limit: 25
        )
        XCTAssertEqual(firstPage.orders.count, 25)
        XCTAssertFalse(firstPage.orders.contains { $0.id == "needle-order" })
        let cursor = try XCTUnwrap(firstPage.nextCursor)

        let secondPage = try repository.fetchOrderPage(
            query: .all(searchText: ""),
            after: cursor,
            limit: 25
        )
        XCTAssertEqual(secondPage.orders.count, 5)
        XCTAssertTrue(secondPage.orders.contains { $0.id == "needle-order" })

        let searchPage = try repository.fetchOrderPage(
            query: .all(searchText: "Needle"),
            after: nil,
            limit: 25
        )
        XCTAssertEqual(searchPage.orders.map(\.id), ["needle-order"])
        XCTAssertNil(searchPage.nextCursor)
    }

    func testThousandOrderFixtureKeepsMainPagesBoundedIndexedAndUsesBoundedStatements() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextGeneratedID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextGeneratedID += 1
                return "scale-generated-\(nextGeneratedID)"
            }
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let customerId = "scale-customer"
        try repository.save(
            Customer(
                id: customerId,
                name: "Scale Customer",
                phone: "5550199",
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
        for index in 0..<1_000 {
            let status: OrderStatus
            switch index % 6 {
            case 0:
                status = .draft
            case 1:
                status = .confirmed
            case 2:
                status = .inProgress
            case 3:
                status = .ready
            case 4:
                status = .completed
            default:
                status = .cancelled
            }
            let order = pagedOrder(
                id: "scale-\(String(format: "%04d", index))",
                customerId: index.isMultiple(of: 3) ? customerId : nil,
                status: status,
                dueAt: now.addingTimeInterval(
                    TimeInterval(index * 3_600)
                ),
                quotedPrice: status == .completed ? 100 : nil,
                depositPaid: status == .completed ? 25 : nil
            )
            try repository.save(orderWithoutRecordedPayment(order))
            if status == .completed {
                for receiptIndex in 0..<13 {
                    _ = try repository.recordPayment(
                        orderId: order.id,
                        amount: receiptIndex == 12 ? 1 : 2,
                        receivedAt: now.addingTimeInterval(
                            TimeInterval(receiptIndex)
                        ),
                        note: nil,
                        createdAt: now.addingTimeInterval(
                            TimeInterval(receiptIndex)
                        )
                    )
                }
            }
            if [.confirmed, .inProgress, .ready].contains(status) {
                try repository.saveOrderReminderConfiguration(
                    .initialDefault,
                    orderId: order.id,
                    updatedAt: now
                )
            }
        }

        let recorder = SQLStatementRecorder()
        repository.writer.writeWithoutTransaction { db in
            db.trace(options: .statement) { event in
                recorder.record(event.expandedDescription)
            }
        }

        let active = try measuredPage(recorder: recorder) {
            try repository.fetchOrderPage(
                query: .active(dueAtRange: nil),
                after: nil,
                limit: 25
            )
        }
        let completed = try measuredPage(recorder: recorder) {
            try repository.fetchOrderPage(
                query: .completed,
                after: nil,
                limit: 25
            )
        }
        let customer = try measuredPage(recorder: recorder) {
            try repository.fetchOrderPage(
                query: .customer(id: customerId),
                after: nil,
                limit: 25
            )
        }
        let upcoming = try measuredPage(recorder: recorder) {
            try repository.fetchOrderPage(
                query: .upcoming(
                    from: now,
                    through: now.addingTimeInterval(30 * 24 * 60 * 60)
                ),
                after: nil,
                limit: 25
            )
        }

        XCTAssertEqual(active.orders.count, 25)
        XCTAssertEqual(completed.orders.count, 25)
        XCTAssertEqual(customer.orders.count, 25)
        XCTAssertEqual(upcoming.orders.count, 25)

        let receiptCount = try repository.writer.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM payment_receipts"
            ) ?? 0
        }
        XCTAssertEqual(receiptCount, 2_158)

        let reportRange = ReportDateRange(
            start: now.addingTimeInterval(-1),
            end: now.addingTimeInterval(1_000 * 3_600)
        )
        let reportStatuses: Set<OrderStatus> = [
            .confirmed, .inProgress, .ready, .completed,
        ]

        recorder.reset()
        let receivedPage = try repository.fetchReceivedPaymentPage(
            dateRange: reportRange,
            statuses: reportStatuses,
            after: nil,
            limit: 25
        )
        XCTAssertEqual(receivedPage.rows.count, 25)
        XCTAssertNotNil(receivedPage.nextCursor)
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )
        let receivedStatement = try XCTUnwrap(
            recorder.recordedStatements.first {
                $0.contains("FROM payment_receipts")
                    && $0.contains("ORDER BY payment_receipts.received_at_unix_time")
            }
        )
        let receivedPlan = try expandedQueryPlan(
            repository: repository,
            sql: receivedStatement
        )
        XCTAssertTrue(
            receivedPlan.contains {
                $0.contains("payment_receipts_on_order_received_at_id")
            },
            receivedPlan.joined(separator: "\n")
        )

        recorder.reset()
        let outstandingPage = try repository.fetchOutstandingPaymentOrderPage(
            dateRange: reportRange,
            statuses: reportStatuses,
            after: nil,
            limit: 25
        )
        XCTAssertEqual(outstandingPage.orders.count, 25)
        XCTAssertNotNil(outstandingPage.nextCursor)
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )
        let outstandingStatement = try XCTUnwrap(
            recorder.recordedStatements.first {
                $0.contains("cloudbake_has_outstanding")
                    && $0.contains("ORDER BY orders.due_at_unix_time")
            }
        )
        let outstandingPlan = try expandedQueryPlan(
            repository: repository,
            sql: outstandingStatement
        )
        XCTAssertTrue(
            outstandingPlan.contains {
                $0.contains("orders_on_status_due_id")
            },
            outstandingPlan.joined(separator: "\n")
        )

        recorder.reset()
        let salesSummaries = try repository.fetchSalesOrderSummaries(
            dateRanges: [reportRange],
            statuses: reportStatuses
        )
        XCTAssertEqual(salesSummaries.count, 1)
        XCTAssertEqual(salesSummaries[0].orderCount, 667)
        XCTAssertEqual(salesSummaries[0].receivedTotal, 4_150)
        XCTAssertEqual(salesSummaries[0].outstandingTotal, 12_450)
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )

        recorder.reset()
        let reminderOccurrences =
            try repository.fetchScheduledOrderReminderOccurrences(
                after: now,
                limit: 60
            )
        XCTAssertEqual(reminderOccurrences.count, 60)
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )
        let reminderStatement = try XCTUnwrap(
            recorder.recordedStatements.first {
                $0.contains("WITH reminder_occurrences")
            }
        )
        let reminderPlan = try expandedQueryPlan(
            repository: repository,
            sql: reminderStatement
        )
        XCTAssertTrue(
            reminderPlan.contains {
                $0.contains("orders_on_status_due_id")
            },
            reminderPlan.joined(separator: "\n")
        )

        recorder.reset()
        let paymentSummary = try repository.fetchPaymentPendingSummary(
            at: now.addingTimeInterval(1_000 * 3_600)
        )
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )
        XCTAssertEqual(
            recorder.recordedStatements.filter {
                $0.contains("COUNT(*)") && $0.contains("FROM orders")
            }.count,
            1
        )
        XCTAssertEqual(paymentSummary.orderCount, 166)
        XCTAssertEqual(paymentSummary.totalBalance, 12_450)

        let activePlan = try orderQueryPlan(
            repository: repository,
            indexName: "orders_on_status_due_id",
            predicate: "status IN (?, ?, ?, ?)",
            arguments: [
                OrderStatus.draft.rawValue,
                OrderStatus.confirmed.rawValue,
                OrderStatus.inProgress.rawValue,
                OrderStatus.ready.rawValue,
            ]
        )
        XCTAssertTrue(
            activePlan.contains {
                $0.contains("orders_on_status_due_id")
            },
            activePlan.joined(separator: "\n")
        )

        let customerPlan = try orderQueryPlan(
            repository: repository,
            indexName: "orders_on_customer_due_id",
            predicate: "customer_id = ?",
            arguments: [customerId]
        )
        XCTAssertTrue(
            customerPlan.contains {
                $0.contains("orders_on_customer_due_id")
            },
            customerPlan.joined(separator: "\n")
        )

        let paymentPlan = try orderQueryPlan(
            repository: repository,
            indexName: "orders_on_status_due_id",
            predicate: """
                status = ?
                AND due_at_unix_time <= ?
                AND quoted_price_decimal IS NOT NULL
                AND CAST(quoted_price_decimal AS NUMERIC)
                    > COALESCE(CAST(deposit_paid_decimal AS NUMERIC), 0)
                """,
            arguments: [
                OrderStatus.completed.rawValue,
                now.addingTimeInterval(1_000 * 3_600).timeIntervalSince1970,
            ]
        )
        XCTAssertTrue(
            paymentPlan.contains {
                $0.contains("orders_on_status_due_id")
            },
            paymentPlan.joined(separator: "\n")
        )
    }

    func testProjectedIngredientDemandAggregatesLiveAndReservedOrdersInSQL() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let flour = InventoryItem(
            id: "inventory-flour",
            name: "Flour",
            unit: .gram,
            currentQuantity: 1_100,
            minimumQuantity: 200,
            createdAt: now,
            updatedAt: now
        )
        let milk = InventoryItem(
            id: "inventory-milk",
            name: "Milk",
            unit: .milliliter,
            currentQuantity: 1_000,
            minimumQuantity: 100,
            createdAt: now,
            updatedAt: now
        )
        try repository.save(flour)
        try repository.save(milk)
        try repository.save(
            InventoryStockBatch(
                id: "batch-flour-usable",
                inventoryItemId: flour.id,
                remainingQuantity: 100,
                expiresAt: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        try repository.save(
            InventoryStockBatch(
                id: "batch-flour-expired",
                inventoryItemId: flour.id,
                remainingQuantity: 1_000,
                expiresAt: now.addingTimeInterval(-1),
                createdAt: now,
                updatedAt: now
            )
        )
        let recipe = Recipe(
            id: "recipe-cake",
            name: "Cake",
            notes: nil,
            createdAt: now,
            updatedAt: now
        )
        let component = RecipeComponent(
            id: "component-batter",
            recipeId: recipe.id,
            name: "Batter",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )
        try repository.save(recipe)
        try repository.save(component)
        try repository.save(
            RecipeIngredient(
                id: "ingredient-flour",
                componentId: component.id,
                inventoryItemId: flour.id,
                quantity: 0.2,
                unit: .kilogram,
                note: nil,
                createdAt: now,
                updatedAt: now
            )
        )
        let draftOrder = demandOrder(
            id: "order-draft",
            recipeId: recipe.id,
            scale: 2,
            status: .draft,
            timestamp: now
        )
        try repository.saveOrder(
            draftOrder,
            replacingExtraIngredients: [
                OrderExtraIngredient(
                    id: "extra-milk",
                    orderId: draftOrder.id,
                    inventoryItemId: milk.id,
                    quantity: 1,
                    unit: .tablespoon,
                    note: nil,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            allowInventoryShortage: true
        )
        let confirmedOrder = demandOrder(
            id: "order-confirmed",
            recipeId: recipe.id,
            scale: 1,
            status: .confirmed,
            timestamp: now
        )
        try repository.saveOrder(
            confirmedOrder,
            replacingExtraIngredients: [
                OrderExtraIngredient(
                    id: "extra-flour",
                    orderId: confirmedOrder.id,
                    inventoryItemId: flour.id,
                    quantity: 100,
                    unit: .gram,
                    note: nil,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            allowInventoryShortage: true
        )

        let summary = try repository.fetchProjectedIngredientDemandSummary(at: now)

        XCTAssertEqual(summary.neededInventoryItemIds, [flour.id, milk.id])
        let shortage = try XCTUnwrap(summary.shortages.first)
        XCTAssertEqual(summary.shortages.count, 1)
        XCTAssertEqual(shortage.inventoryItemId, flour.id)
        XCTAssertEqual(shortage.requiredQuantity, 700, accuracy: 0.001)
        XCTAssertEqual(shortage.availableQuantity, 100, accuracy: 0.001)
        XCTAssertEqual(shortage.orderIds, [draftOrder.id, confirmedOrder.id])
    }

    private func measuredPage(
        recorder: SQLStatementRecorder,
        operation: () throws -> OrderPage
    ) throws -> OrderPage {
        recorder.reset()
        let page = try operation()
        XCTAssertLessThanOrEqual(
            recorder.statementCount,
            5,
            recorder.recordedStatements.joined(separator: "\n")
        )
        XCTAssertEqual(
            recorder.recordedStatements.filter {
                $0.contains("SELECT *") && $0.contains("FROM orders")
            }.count,
            1
        )
        return page
    }

    func testPaymentReceiptsAtomicallyUpdateDerivedPaidTotal() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextID += 1
                return "payment-entry-\(nextID)"
            }
        )
        let dueAt = Date(timeIntervalSince1970: 1_800_000_000)
        let firstReceivedAt = dueAt.addingTimeInterval(86_400)
        let secondReceivedAt = dueAt.addingTimeInterval(172_800)
        try repository.save(
            pagedOrder(
                id: "receipt-order",
                status: .completed,
                dueAt: dueAt,
                quotedPrice: 100
            )
        )

        let partial = try repository.recordPayment(
            orderId: "receipt-order",
            amount: 25,
            receivedAt: firstReceivedAt,
            note: " Deposit ",
            createdAt: firstReceivedAt
        )
        let remaining = try repository.recordRemainingBalancePayment(
            orderId: "receipt-order",
            receivedAt: secondReceivedAt,
            note: nil,
            createdAt: secondReceivedAt
        )

        XCTAssertEqual(partial.amount, 25)
        XCTAssertEqual(partial.note, "Deposit")
        XCTAssertEqual(remaining.amount, 75)
        XCTAssertEqual(
            try repository.fetchPaymentReceipts(orderId: "receipt-order"),
            [remaining, partial]
        )
        XCTAssertEqual(try repository.fetchOrder(id: "receipt-order")?.depositPaid, 100)
        XCTAssertEqual(try repository.fetchLegacyPaidAmount(orderId: "receipt-order"), 0)
    }

    func testOpeningPaymentIsAtomicWithNewOrder() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: { "opening-receipt" }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let order = pagedOrder(
            id: "opening-payment-order",
            status: .confirmed,
            dueAt: timestamp,
            quotedPrice: 100
        )

        try repository.saveOrder(
            order,
            replacingExtraIngredients: [],
            reminderConfiguration: .initialDefault,
            openingPayment: NewPaymentReceipt(
                amount: 25,
                receivedAt: timestamp,
                note: "Opening deposit",
                createdAt: timestamp
            ),
            allowInventoryShortage: false
        )

        XCTAssertEqual(
            try repository.fetchOrder(id: order.id)?.depositPaid,
            25
        )
        XCTAssertEqual(
            try repository.fetchPaymentReceipts(orderId: order.id).map(\.amount),
            [25]
        )
    }

    func testNewOrderChecklistIsSavedAtomicallyWithOrder() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let order = pagedOrder(
            id: "checklist-order",
            status: .draft,
            dueAt: timestamp
        )
        let checklistItem = OrderChecklistItem(
            id: "checklist-decoration",
            orderId: order.id,
            title: "Finish decoration",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try repository.saveOrder(
            order,
            replacingExtraIngredients: [],
            replacingChecklistItems: [checklistItem],
            reminderConfiguration: .initialDefault,
            openingPayment: nil,
            allowInventoryShortage: false
        )

        XCTAssertEqual(try repository.fetchOrder(id: order.id), order)
        XCTAssertEqual(
            try repository.fetchOrderChecklistItems(orderId: order.id),
            [checklistItem]
        )
    }

    func testMismatchedNewOrderChecklistRollsBackOrder() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let order = pagedOrder(
            id: "rolled-back-checklist-order",
            status: .draft,
            dueAt: timestamp
        )
        let invalidChecklistItem = OrderChecklistItem(
            id: "orphan-checklist",
            orderId: "missing-order",
            title: "Cannot persist",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        XCTAssertThrowsError(
            try repository.saveOrder(
                order,
                replacingExtraIngredients: [],
                replacingChecklistItems: [invalidChecklistItem],
                reminderConfiguration: .initialDefault,
                openingPayment: nil,
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderChecklistPersistenceError,
                .parentOrderMismatch
            )
        }

        XCTAssertNil(try repository.fetchOrder(id: order.id))
        XCTAssertEqual(
            try repository.fetchOrderChecklistItems(orderId: order.id),
            []
        )
    }

    func testExistingChecklistCannotBeMovedWhileSavingAnotherOrder() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let existingOrder = pagedOrder(
            id: "existing-checklist-order",
            status: .confirmed,
            dueAt: timestamp
        )
        let existingItem = OrderChecklistItem(
            id: "owned-checklist",
            orderId: existingOrder.id,
            title: "Keep ownership",
            isCompleted: true,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try repository.save(existingOrder)
        try repository.save(existingItem)
        let newOrder = pagedOrder(
            id: "new-checklist-order",
            status: .draft,
            dueAt: timestamp
        )
        let reassignedItem = OrderChecklistItem(
            id: existingItem.id,
            orderId: newOrder.id,
            title: "Move ownership",
            isCompleted: false,
            sortOrder: 0,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        XCTAssertThrowsError(
            try repository.saveOrder(
                newOrder,
                replacingExtraIngredients: [],
                replacingChecklistItems: [reassignedItem],
                reminderConfiguration: .initialDefault,
                openingPayment: nil,
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? OrderChecklistPersistenceError,
                .itemBelongsToAnotherOrder
            )
        }

        XCTAssertNil(try repository.fetchOrder(id: newOrder.id))
        XCTAssertEqual(
            try repository.fetchOrderChecklistItems(orderId: existingOrder.id),
            [existingItem]
        )
    }

    func testInvalidOpeningPaymentRollsBackNewOrder() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let order = pagedOrder(
            id: "invalid-opening-payment",
            status: .confirmed,
            dueAt: timestamp,
            quotedPrice: 100
        )

        XCTAssertThrowsError(
            try repository.saveOrder(
                order,
                replacingExtraIngredients: [],
                reminderConfiguration: .initialDefault,
                openingPayment: NewPaymentReceipt(
                    amount: 125,
                    receivedAt: timestamp,
                    note: nil,
                    createdAt: timestamp
                ),
                allowInventoryShortage: false
            )
        ) { error in
            XCTAssertEqual(
                error as? PaymentReceiptPersistenceError,
                .exceedsBalance
            )
        }
        XCTAssertNil(try repository.fetchOrder(id: order.id))
        XCTAssertEqual(
            try repository.fetchPaymentReceipts(orderId: order.id),
            []
        )
    }

    func testFailedPaymentInsertRollsBackDerivedPaidTotal() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: { "duplicate-receipt" }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.save(
            pagedOrder(
                id: "payment-rollback",
                status: .completed,
                dueAt: timestamp,
                quotedPrice: 100
            )
        )
        _ = try repository.recordPayment(
            orderId: "payment-rollback",
            amount: 25,
            receivedAt: timestamp,
            note: nil,
            createdAt: timestamp
        )

        XCTAssertThrowsError(
            try repository.recordPayment(
                orderId: "payment-rollback",
                amount: 10,
                receivedAt: timestamp,
                note: nil,
                createdAt: timestamp
            )
        )
        XCTAssertEqual(try repository.fetchOrder(id: "payment-rollback")?.depositPaid, 25)
        XCTAssertEqual(
            try repository.fetchPaymentReceipts(orderId: "payment-rollback").map(\.amount),
            [25]
        )
    }

    func testDirectOrderSaveCannotOverwriteDerivedPaidTotal() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let order = pagedOrder(
            id: "protected-paid-total",
            status: .completed,
            dueAt: timestamp,
            quotedPrice: 100
        )
        try repository.save(order)
        _ = try repository.recordPayment(
            orderId: order.id,
            amount: 25,
            receivedAt: timestamp,
            note: nil,
            createdAt: timestamp
        )

        XCTAssertThrowsError(
            try repository.save(
                pagedOrder(
                    id: order.id,
                    status: .completed,
                    dueAt: timestamp,
                    quotedPrice: 100,
                    depositPaid: 50
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? PaymentReceiptPersistenceError,
                .directPaidTotalMutation
            )
        }
        XCTAssertEqual(
            try repository.fetchOrder(id: order.id)?.depositPaid,
            25
        )
    }

    func testDirectOrderSaveCannotCreateDerivedPaidTotal() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertThrowsError(
            try repository.save(
                pagedOrder(
                    id: "protected-new-paid-total",
                    status: .confirmed,
                    dueAt: timestamp,
                    quotedPrice: 100,
                    depositPaid: 25
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? PaymentReceiptPersistenceError,
                .directPaidTotalMutation
            )
        }
        XCTAssertNil(try repository.fetchOrder(id: "protected-new-paid-total"))
    }

    func testReceivedPaymentReportIsPagedAndExcludesVoids() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextID += 1
                return "report-entry-\(nextID)"
            }
        )
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 1...3 {
            try repository.save(
                pagedOrder(
                    id: "report-order-\(index)",
                    status: .completed,
                    dueAt: start,
                    quotedPrice: 100
                )
            )
        }
        try repository.save(
            pagedOrder(
                id: "report-order-draft",
                status: .draft,
                dueAt: start,
                quotedPrice: 100
            )
        )
        try repository.save(
            pagedOrder(
                id: "report-order-boundary",
                status: .completed,
                dueAt: start,
                quotedPrice: 100
            )
        )
        let first = try repository.recordPayment(
            orderId: "report-order-1",
            amount: decimal("0.10"),
            receivedAt: start.addingTimeInterval(10),
            note: nil,
            createdAt: start.addingTimeInterval(10)
        )
        let second = try repository.recordPayment(
            orderId: "report-order-2",
            amount: decimal("0.20"),
            receivedAt: start.addingTimeInterval(20),
            note: nil,
            createdAt: start.addingTimeInterval(20)
        )
        let voided = try repository.recordPayment(
            orderId: "report-order-3",
            amount: 1,
            receivedAt: start.addingTimeInterval(30),
            note: nil,
            createdAt: start.addingTimeInterval(30)
        )
        _ = try repository.voidPaymentReceipt(
            receiptId: voided.id,
            reason: nil,
            voidedAt: start.addingTimeInterval(40),
            createdAt: start.addingTimeInterval(40)
        )
        _ = try repository.recordPayment(
            orderId: "report-order-draft",
            amount: 5,
            receivedAt: start.addingTimeInterval(15),
            note: nil,
            createdAt: start.addingTimeInterval(15)
        )
        _ = try repository.recordPayment(
            orderId: "report-order-boundary",
            amount: 10,
            receivedAt: start.addingTimeInterval(60),
            note: nil,
            createdAt: start.addingTimeInterval(60)
        )
        let range = ReportDateRange(
            start: start,
            end: start.addingTimeInterval(60)
        )

        let firstPage = try repository.fetchReceivedPaymentPage(
            dateRange: range,
            statuses: [.confirmed, .inProgress, .ready, .completed],
            after: nil,
            limit: 1
        )
        let secondPage = try repository.fetchReceivedPaymentPage(
            dateRange: range,
            statuses: [.confirmed, .inProgress, .ready, .completed],
            after: firstPage.nextCursor,
            limit: 1
        )
        let summary = try repository.fetchPaymentLedgerSummary(
            dateRange: range,
            statuses: [.confirmed, .inProgress, .ready, .completed]
        )

        XCTAssertEqual(firstPage.rows.map(\.receipt.id), [second.id])
        XCTAssertNotNil(firstPage.nextCursor)
        XCTAssertEqual(secondPage.rows.map(\.receipt.id), [first.id])
        XCTAssertNil(secondPage.nextCursor)
        XCTAssertEqual(summary.receivedTotal, decimal("0.30"))
        XCTAssertEqual(summary.receivedCount, 2)
    }

    func testOutstandingPaymentReportFiltersStatusesAndPaginates() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextID += 1
                return "outstanding-entry-\(nextID)"
            }
        )
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.save(
            pagedOrder(
                id: "confirmed-outstanding",
                status: .confirmed,
                dueAt: start.addingTimeInterval(10),
                quotedPrice: 100
            )
        )
        try repository.save(
            pagedOrder(
                id: "completed-outstanding",
                status: .completed,
                dueAt: start.addingTimeInterval(20),
                quotedPrice: 80
            )
        )
        try repository.save(
            pagedOrder(
                id: "draft-outstanding",
                status: .draft,
                dueAt: start.addingTimeInterval(30),
                quotedPrice: 90
            )
        )
        _ = try repository.recordPayment(
            orderId: "confirmed-outstanding",
            amount: 25,
            receivedAt: start,
            note: nil,
            createdAt: start
        )
        _ = try repository.recordRemainingBalancePayment(
            orderId: "completed-outstanding",
            receivedAt: start,
            note: nil,
            createdAt: start
        )
        let range = ReportDateRange(
            start: start,
            end: start.addingTimeInterval(60)
        )
        let statuses: Set<OrderStatus> = [
            .confirmed, .inProgress, .ready, .completed,
        ]

        let page = try repository.fetchOutstandingPaymentOrderPage(
            dateRange: range,
            statuses: statuses,
            after: nil,
            limit: 1
        )
        let summary = try repository.fetchPaymentLedgerSummary(
            dateRange: range,
            statuses: statuses
        )
        let sales = try repository.fetchSalesOrderSummary(
            dateRange: range,
            statuses: statuses
        )

        XCTAssertEqual(page.orders.map(\.id), ["confirmed-outstanding"])
        XCTAssertNil(page.nextCursor)
        XCTAssertEqual(summary.outstandingTotal, 75)
        XCTAssertEqual(summary.outstandingOrderCount, 1)
        XCTAssertEqual(sales.orderCount, 2)
        XCTAssertEqual(sales.quotedTotal, 180)
        XCTAssertEqual(sales.averageQuotedValue, 90)
        XCTAssertEqual(sales.receivedTotal, 105)
        XCTAssertEqual(sales.outstandingTotal, 75)
        XCTAssertEqual(sales.statusCounts[.confirmed], 1)
        XCTAssertEqual(sales.statusCounts[.completed], 1)
    }

    func testOutstandingPaymentPageUsesExactDecimalComparison() throws {
        let repository = try AppDatabase.makeInMemory().makeCoreDataRepository()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let quotedPrice = decimal("9007199254740993")
        let paidAmount = decimal("9007199254740992")
        let order = pagedOrder(
            id: "exact-decimal-outstanding",
            status: .completed,
            dueAt: start.addingTimeInterval(10),
            quotedPrice: quotedPrice
        )
        try repository.save(order)
        _ = try repository.recordPayment(
            orderId: order.id,
            amount: paidAmount,
            receivedAt: start,
            note: nil,
            createdAt: start
        )

        let page = try repository.fetchOutstandingPaymentOrderPage(
            dateRange: ReportDateRange(
                start: start,
                end: start.addingTimeInterval(60)
            ),
            statuses: [.completed],
            after: nil,
            limit: 25
        )

        XCTAssertEqual(page.orders.map(\.id), [order.id])
        XCTAssertEqual(page.orders.first?.balanceDue, 1)
    }

    func testSalesReportAggregatesAllDailyBucketsInOneBoundedQuery() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let ranges = (0..<366).map { day in
            let bucketStart = start.addingTimeInterval(
                TimeInterval(day * 86_400)
            )
            return ReportDateRange(
                start: bucketStart,
                end: bucketStart.addingTimeInterval(86_400)
            )
        }
        try repository.save(
            pagedOrder(
                id: "first-sales-bucket",
                status: .confirmed,
                dueAt: start.addingTimeInterval(60),
                quotedPrice: decimal("0.10")
            )
        )
        try repository.save(
            pagedOrder(
                id: "last-sales-bucket",
                status: .completed,
                dueAt: ranges[365].start.addingTimeInterval(60),
                quotedPrice: decimal("0.20")
            )
        )

        let summaries = try repository.fetchSalesOrderSummaries(
            dateRanges: ranges,
            statuses: [.confirmed, .completed]
        )

        XCTAssertEqual(summaries.count, 366)
        XCTAssertEqual(summaries[0].orderCount, 1)
        XCTAssertEqual(summaries[0].quotedTotal, decimal("0.10"))
        XCTAssertEqual(summaries[180].orderCount, 0)
        XCTAssertEqual(summaries[365].orderCount, 1)
        XCTAssertEqual(summaries[365].quotedTotal, decimal("0.20"))
    }

    func testVoidingReceiptAppendsCorrectionAndReconcilesPaidTotal() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextID += 1
                return "payment-entry-\(nextID)"
            }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.save(
            pagedOrder(
                id: "void-payment",
                status: .completed,
                dueAt: timestamp,
                quotedPrice: 100
            )
        )
        let receipt = try repository.recordPayment(
            orderId: "void-payment",
            amount: 40,
            receivedAt: timestamp,
            note: nil,
            createdAt: timestamp
        )

        let correction = try repository.voidPaymentReceipt(
            receiptId: receipt.id,
            reason: " Wrong amount ",
            voidedAt: timestamp.addingTimeInterval(60),
            createdAt: timestamp.addingTimeInterval(60)
        )

        XCTAssertEqual(correction.reason, "Wrong amount")
        XCTAssertEqual(try repository.fetchOrder(id: "void-payment")?.depositPaid, 0)
        XCTAssertEqual(
            try repository.fetchPaymentReceipts(orderId: "void-payment").first?.void,
            correction
        )
        XCTAssertThrowsError(
            try repository.voidPaymentReceipt(
                receiptId: receipt.id,
                reason: nil,
                voidedAt: timestamp.addingTimeInterval(120),
                createdAt: timestamp.addingTimeInterval(120)
            )
        ) { error in
            XCTAssertEqual(
                error as? PaymentReceiptPersistenceError,
                .alreadyVoided
            )
        }
    }

    func testVoidingReceiptRejectsInconsistentPaidTotalWithoutCorrection() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        try AppDatabaseMigrations.makeMigrator().migrate(queue)
        var nextID = 0
        let repository = GRDBCoreDataRepository(
            writer: queue,
            idProvider: {
                nextID += 1
                return "payment-entry-\(nextID)"
            }
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.save(
            pagedOrder(
                id: "corrupt-payment-total",
                status: .completed,
                dueAt: timestamp,
                quotedPrice: 100
            )
        )
        let receipt = try repository.recordPayment(
            orderId: "corrupt-payment-total",
            amount: 40,
            receivedAt: timestamp,
            note: nil,
            createdAt: timestamp
        )
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE orders
                    SET deposit_paid_decimal = '10'
                    WHERE id = 'corrupt-payment-total'
                    """
            )
        }

        XCTAssertThrowsError(
            try repository.voidPaymentReceipt(
                receiptId: receipt.id,
                reason: "Should roll back",
                voidedAt: timestamp.addingTimeInterval(60),
                createdAt: timestamp.addingTimeInterval(60)
            )
        ) { error in
            XCTAssertEqual(
                error as? PaymentReceiptPersistenceError,
                .invalidStoredAmount
            )
        }
        XCTAssertNil(
            try repository.fetchPaymentReceipts(
                orderId: "corrupt-payment-total"
            ).first?.void
        )
        XCTAssertEqual(
            try repository.fetchOrder(id: "corrupt-payment-total")?.depositPaid,
            10
        )
    }

    private func orderQueryPlan(
        repository: GRDBCoreDataRepository,
        indexName: String,
        predicate: String,
        arguments: [any DatabaseValueConvertible]
    ) throws -> [String] {
        try repository.writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    EXPLAIN QUERY PLAN
                    SELECT *
                    FROM orders INDEXED BY \(indexName)
                    WHERE \(predicate)
                    ORDER BY due_at_unix_time, id
                    LIMIT 26
                    """,
                arguments: StatementArguments(arguments)
            ).map { row in
                row["detail"]
            }
        }
    }

    private func expandedQueryPlan(
        repository: GRDBCoreDataRepository,
        sql: String
    ) throws -> [String] {
        try repository.writer.read { db in
            try Row.fetchAll(
                db,
                sql: "EXPLAIN QUERY PLAN \(sql)"
            ).map { row in
                row["detail"]
            }
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

    private func demandOrder(
        id: String,
        recipeId: String,
        scale: Decimal,
        status: OrderStatus,
        timestamp: Date
    ) -> Order {
        Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            recipeId: recipeId,
            recipeScaleMultiplier: scale,
            title: id,
            customerName: "Customer",
            status: status,
            dueAt: timestamp.addingTimeInterval(3_600),
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

}

private final class SQLStatementRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var statements: [String] = []

    var statementCount: Int {
        lock.withLock {
            statements.count
        }
    }

    var recordedStatements: [String] {
        lock.withLock {
            statements
        }
    }

    func record(_ statement: String) {
        lock.withLock {
            statements.append(statement)
        }
    }

    func reset() {
        lock.withLock {
            statements.removeAll(keepingCapacity: true)
        }
    }
}
