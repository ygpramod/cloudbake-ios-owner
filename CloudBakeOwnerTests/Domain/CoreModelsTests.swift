import XCTest
@testable import CloudBakeOwner

final class CoreModelsTests: XCTestCase {
    func testInventoryUnitsCoverOwnerRecipeMeasurements() {
        XCTAssertEqual(InventoryUnit.kilogram.rawValue, "kilogram")
        XCTAssertEqual(InventoryUnit.gram.rawValue, "gram")
        XCTAssertEqual(InventoryUnit.liter.rawValue, "liter")
        XCTAssertEqual(InventoryUnit.milliliter.rawValue, "milliliter")
        XCTAssertEqual(InventoryUnit.teaspoon.rawValue, "teaspoon")
        XCTAssertEqual(InventoryUnit.tablespoon.rawValue, "tablespoon")
        XCTAssertEqual(InventoryUnit.cup.rawValue, "cup")
    }

    func testInventoryUnitsConvertWithinWeightFamily() {
        XCTAssertEqual(InventoryUnit.kilogram.convertedQuantity(1.5, to: .gram), 1_500)
        XCTAssertEqual(InventoryUnit.gram.convertedQuantity(750, to: .kilogram), 0.75)
    }

    func testInventoryUnitsConvertWithinVolumeFamily() {
        XCTAssertEqual(InventoryUnit.liter.convertedQuantity(2, to: .milliliter), 2_000)
        XCTAssertEqual(InventoryUnit.tablespoon.convertedQuantity(2, to: .milliliter), 30)
        XCTAssertEqual(InventoryUnit.cup.convertedQuantity(1, to: .milliliter), 240)
    }

    func testInventoryUnitsDoNotConvertAcrossFamilies() {
        XCTAssertNil(InventoryUnit.gram.convertedQuantity(100, to: .milliliter))
        XCTAssertNil(InventoryUnit.each.convertedQuantity(1, to: .gram))
    }

    func testOrderStatusStartsWithDraftAndConfirmedStates() {
        XCTAssertEqual(OrderStatus.draft.rawValue, "draft")
        XCTAssertEqual(OrderStatus.confirmed.rawValue, "confirmed")
        XCTAssertEqual(OrderStatus.inProgress.rawValue, "inProgress")
        XCTAssertEqual(OrderStatus.ready.rawValue, "ready")
        XCTAssertEqual(OrderStatus.completed.rawValue, "completed")
        XCTAssertEqual(OrderStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(OrderFulfillmentType.pickup.rawValue, "pickup")
        XCTAssertEqual(OrderFulfillmentType.delivery.rawValue, "delivery")
    }

    func testOrderPhotoKindCapturesReferenceAndFinalCakeStates() {
        XCTAssertEqual(OrderPhotoKind.customerReference.rawValue, "customerReference")
        XCTAssertEqual(OrderPhotoKind.finalCake.rawValue, "finalCake")
        XCTAssertEqual(OrderPhotoKind.allCases, [.customerReference, .finalCake])
    }

    func testOrderPaymentSummaryDerivesStatusAndBalance() {
        let timestamp = Date(timeIntervalSince1970: 1_800_120_000)
        let order = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: nil,
            title: "Vanilla Birthday",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            quotedPrice: Decimal(150),
            depositPaid: Decimal(50),
            paymentNotes: "Deposit received",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        XCTAssertEqual(order.balanceDue, Decimal(100))
        XCTAssertEqual(order.paymentStatus, "Part Paid")

        let paidOrder = Order(
            id: "order-paid",
            customerId: nil,
            cakeDesignId: nil,
            title: "Paid Cake",
            customerName: "Amy",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            quotedPrice: Decimal(150),
            depositPaid: Decimal(150),
            createdAt: timestamp,
            updatedAt: timestamp
        )

        XCTAssertEqual(paidOrder.balanceDue, Decimal(0))
        XCTAssertEqual(paidOrder.paymentStatus, "Paid")
    }

    func testConsumerOrderPreviewProjectsCustomerSafeOrderFields() {
        let timestamp = Date(timeIntervalSince1970: 1_800_120_000)
        let order = Order(
            id: "order-vanilla",
            customerId: "customer-amy",
            cakeDesignId: "design-flowers",
            recipeId: "recipe-private",
            title: "Vanilla Birthday",
            customerName: "Amy Private",
            status: .confirmed,
            dueAt: timestamp,
            fulfillmentType: .delivery,
            deliveryAddress: "Private address",
            cakeNotes: "Owner-only buttercream note",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let design = CakeDesign(
            id: "design-flowers",
            name: "Pink Floral Cake",
            notes: "Owner-only design correction",
            photoReference: "cloudbake://designs/pink-floral.jpg",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let preview = ConsumerOrderPreview(order: order, cakeDesign: design)

        XCTAssertEqual(
            preview,
            ConsumerOrderPreview(
                orderId: "order-vanilla",
                cakeName: "Vanilla Birthday",
                status: .accepted,
                dueAt: timestamp,
                fulfillmentType: .delivery,
                designName: "Pink Floral Cake",
                designPhotoReference: "cloudbake://designs/pink-floral.jpg"
            )
        )
    }

    func testConsumerOrderPreviewDoesNotExposeOwnerOnlyFields() {
        let timestamp = Date(timeIntervalSince1970: 1_800_120_000)
        let order = Order(
            id: "order-vanilla",
            customerId: "customer-amy",
            cakeDesignId: nil,
            recipeId: "recipe-private",
            title: "Vanilla Birthday",
            customerName: "Amy Private",
            status: .draft,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: "Private address",
            cakeNotes: "Owner-only buttercream note",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let preview = ConsumerOrderPreview(order: order)
        let exposedFieldNames = Set(Mirror(reflecting: preview).children.compactMap(\.label))

        XCTAssertFalse(exposedFieldNames.contains("customerId"))
        XCTAssertFalse(exposedFieldNames.contains("customerName"))
        XCTAssertFalse(exposedFieldNames.contains("recipeId"))
        XCTAssertFalse(exposedFieldNames.contains("cakeNotes"))
        XCTAssertFalse(exposedFieldNames.contains("deliveryAddress"))
    }

    func testConsumerOrderPreviewStatusMapsOwnerLifecycleToCustomerLanguage() {
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .draft)).status, .requested)
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .confirmed)).status, .accepted)
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .inProgress)).status, .inProgress)
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .ready)).status, .ready)
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .completed)).status, .fulfilled)
        XCTAssertEqual(ConsumerOrderPreview(order: makeOrder(status: .cancelled)).status, .cancelled)
    }

    func testCustomerRequiresExplicitNameAndPhoneInModel() {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let customer = Customer(
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

        XCTAssertEqual(customer.name, "Amy")
        XCTAssertEqual(customer.phone, "5550101")
    }

    func testConsumerCustomerProfileProjectsCustomerSafeContactFields() {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Chocolate",
            dislikes: "Fondant",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Owner-only handling note",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let profile = ConsumerCustomerProfile(customer: customer)

        XCTAssertEqual(
            profile,
            ConsumerCustomerProfile(
                customerId: "customer-amy",
                displayName: "Amy",
                contactPhone: "5550101",
                contactEmail: "amy@example.com"
            )
        )
    }

    func testConsumerCustomerProfileDoesNotExposeOwnerOnlyFields() {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Chocolate",
            dislikes: "Fondant",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Owner-only handling note",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let profile = ConsumerCustomerProfile(customer: customer)
        let exposedFieldNames = Set(Mirror(reflecting: profile).children.compactMap(\.label))

        XCTAssertFalse(exposedFieldNames.contains("address"))
        XCTAssertFalse(exposedFieldNames.contains("likes"))
        XCTAssertFalse(exposedFieldNames.contains("dislikes"))
        XCTAssertFalse(exposedFieldNames.contains("allergies"))
        XCTAssertFalse(exposedFieldNames.contains("dietaryRestrictions"))
        XCTAssertFalse(exposedFieldNames.contains("notes"))
        XCTAssertFalse(exposedFieldNames.contains("createdAt"))
        XCTAssertFalse(exposedFieldNames.contains("updatedAt"))
    }

    func testInventoryItemIsLowStockWhenCurrentQuantityIsBelowMinimumQuantity() {
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertTrue(item.isLowStock)
    }

    func testInventoryItemIsNotLowStockWhenCurrentQuantityMeetsMinimumQuantity() {
        let item = InventoryItem(
            id: "inventory-sugar",
            name: "Sugar",
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertFalse(item.isLowStock)
    }

    func testInventoryItemIsLowStockWhenStockIsExpiringSoon() {
        let item = InventoryItem(
            id: "inventory-butter",
            name: "Butter",
            unit: .gram,
            currentQuantity: 750,
            minimumQuantity: 500,
            hasExpiringSoonStock: true,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_000)
        )

        XCTAssertTrue(item.isLowStock)
    }

    func testInventoryItemIsArchivedWhenArchivedAtIsPresent() {
        let item = InventoryItem(
            id: "inventory-old-flour",
            name: "Old flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 500,
            createdAt: Date(timeIntervalSince1970: 1_800_040_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_040_100),
            archivedAt: Date(timeIntervalSince1970: 1_800_040_200)
        )

        XCTAssertTrue(item.isArchived)
    }

    private func makeOrder(status: OrderStatus) -> Order {
        let timestamp = Date(timeIntervalSince1970: 1_800_120_000)
        return Order(
            id: "order-\(status.rawValue)",
            customerId: nil,
            cakeDesignId: nil,
            title: "Vanilla Birthday",
            customerName: "Amy",
            status: status,
            dueAt: timestamp,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
