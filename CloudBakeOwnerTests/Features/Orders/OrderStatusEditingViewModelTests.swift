import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderStatusEditingViewModelTests: XCTestCase {
    func testChangeSelectedOrderStatusToReadyRecordsLinkedRecipeUsage() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .ready))
        XCTAssertEqual(viewModel.selectedOrder?.status, .ready)
        XCTAssertEqual(
            viewModel.selectedOrderRecipeUsage,
            OrderRecipeUsage(
                id: "generated-1",
                orderId: order.id,
                recipeId: "recipe-vanilla",
                usedAt: updatedAt,
                createdAt: updatedAt,
                updatedAt: updatedAt
            )
        )
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
    }

    func testChangeSelectedOrderStatusToCompletedRecordsLinkedRecipeUsage() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .completed))
        XCTAssertEqual(viewModel.selectedOrder?.status, .completed)
        XCTAssertEqual(viewModel.selectedOrderRecipeUsage?.recipeId, "recipe-vanilla")
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
    }

    func testChangeSelectedOrderStatusFromDraftToCompletedRecordsRecipeUsage() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .draft,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated")
        )

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.changeSelectedOrderStatus(to: .completed))
        XCTAssertEqual(viewModel.selectedOrder?.status, .completed)
        XCTAssertEqual(viewModel.selectedOrderRecipeUsage?.recipeId, "recipe-vanilla")
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
    }

    func testChangeSelectedOrderStatusShowsRecipeUsageError() {
        let repository = FakeOrderRepository()
        let order = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: Date(timeIntervalSince1970: 1_800_150_000)
        )
        repository.orders = [order]
        repository.changeOrderStatusError = OrderRecipeUsageError.insufficientStock(itemName: "Cake Flour")
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.changeSelectedOrderStatus(to: .ready))
        XCTAssertEqual(viewModel.selectedOrder?.status, .confirmed)
        XCTAssertEqual(viewModel.errorMessage, "Not enough Cake Flour in inventory.")
    }

    func testBeginViewingUnlinkedOrderClearsLinkedCustomer() {
        let repository = FakeOrderRepository()
        let linkedOrder = makeOrder(
            id: "order-vanilla",
            customerId: "customer-amy",
            recipeId: "recipe-vanilla",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let unlinkedOrder = makeOrder(id: "order-chocolate", dueAt: Date(timeIntervalSince1970: 1_800_150_000))
        repository.customers = [makeCustomer(id: "customer-amy", name: "Amy", allergies: "Nuts")]
        repository.recipes = [makeRecipe(id: "recipe-vanilla", name: "Vanilla sponge")]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(linkedOrder)
        viewModel.beginViewingOrder(unlinkedOrder)

        XCTAssertEqual(viewModel.selectedOrder, unlinkedOrder)
        XCTAssertNil(viewModel.selectedOrderCustomer)
        XCTAssertNil(viewModel.selectedOrderRecipe)
    }

    func testBeginEditingOrderPrefillsDraft() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let order = Order(
            id: "order-vanilla",
            customerId: "customer-amy",
            cakeDesignId: "design-floral",
            recipeId: "recipe-vanilla",
            title: "Vanilla Birthday",
            customerName: "Amy",
            status: .confirmed,
            dueAt: dueAt,
            fulfillmentType: .delivery,
            deliveryAddress: "10 Cake Street",
            cakeNotes: "Pink flowers",
            cakeMessage: "Happy Birthday Amy",
            quotedPrice: Decimal(string: "200"),
            depositPaid: Decimal(string: "50"),
            paymentNotes: "Cash deposit",
            createdAt: Date(timeIntervalSince1970: 1_800_060_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_060_000)
        )
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)
        viewModel.beginEditingOrder()

        XCTAssertEqual(viewModel.draftTitle, "Vanilla Birthday")
        XCTAssertEqual(viewModel.draftCustomerName, "Amy")
        XCTAssertEqual(viewModel.draftCustomerId, "customer-amy")
        XCTAssertEqual(viewModel.draftRecipeId, "recipe-vanilla")
        XCTAssertEqual(viewModel.draftCakeDesignId, "design-floral")
        XCTAssertEqual(viewModel.draftDueAt, dueAt)
        XCTAssertEqual(viewModel.draftStatus, .confirmed)
        XCTAssertEqual(viewModel.draftFulfillmentType, .delivery)
        XCTAssertEqual(viewModel.draftDeliveryAddress, "10 Cake Street")
        XCTAssertEqual(viewModel.draftCakeNotes, "Pink flowers")
        XCTAssertEqual(viewModel.draftCakeMessage, "Happy Birthday Amy")
        XCTAssertEqual(viewModel.draftQuotedPrice, "200")
        XCTAssertEqual(viewModel.draftDepositPaid, "50")
        XCTAssertEqual(viewModel.draftPaymentNotes, "Cash deposit")
    }

    func testSaveEditedOrderPersistsChangesAndStatusTransition() {
        let repository = FakeOrderRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_060_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(id: "order-vanilla", dueAt: dueAt)
        repository.orders = [original]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftTitle = "Chocolate Birthday"
        viewModel.draftCustomerName = "Amy B"
        viewModel.draftRecipeId = "recipe-chocolate"
        viewModel.draftCakeDesignId = "design-floral"
        viewModel.draftStatus = .ready
        viewModel.draftFulfillmentType = .delivery
        viewModel.draftDeliveryAddress = "11 Cake Street"
        viewModel.draftCakeNotes = "Add gold leaf"
        viewModel.draftCakeMessage = "Happy 7th Birthday"
        viewModel.draftQuotedPrice = "175"
        viewModel.draftDepositPaid = "75"
        viewModel.draftPaymentNotes = "Deposit paid by card"

        XCTAssertTrue(viewModel.editedOrderRequiresInventoryDeductionConfirmation)
        XCTAssertTrue(viewModel.saveEditedOrder(confirmingRecipeUsage: true))

        let expected = Order(
            id: "order-vanilla",
            customerId: nil,
            cakeDesignId: "design-floral",
            recipeId: "recipe-chocolate",
            title: "Chocolate Birthday",
            customerName: "Amy B",
            status: .ready,
            dueAt: dueAt,
            fulfillmentType: .delivery,
            deliveryAddress: "11 Cake Street",
            cakeNotes: "Add gold leaf",
            cakeMessage: "Happy 7th Birthday",
            quotedPrice: Decimal(175),
            depositPaid: Decimal(75),
            paymentNotes: "Deposit paid by card",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        XCTAssertEqual(repository.orders, [expected])
        XCTAssertEqual(viewModel.selectedOrder, expected)
        XCTAssertEqual(viewModel.orders, [expected])
        XCTAssertEqual(viewModel.selectedOrderRecipeUsage?.recipeId, "recipe-chocolate")
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedOrderFromConfirmedToReadyRequiresInventoryDeductionConfirmation() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: dueAt
        )
        repository.orders = [original]
        let viewModel = OrderListViewModel(
            repository: repository,
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftStatus = .ready

        XCTAssertTrue(viewModel.editedOrderRequiresInventoryDeductionConfirmation)
        XCTAssertFalse(viewModel.saveEditedOrder())
        XCTAssertEqual(repository.orders, [original])
        XCTAssertNil(viewModel.selectedOrderRecipeUsage)
        XCTAssertEqual(viewModel.errorMessage, "Confirm inventory deduction before saving.")
    }

    func testSaveEditedOrderFromConfirmedToReadyRecordsLinkedRecipeUsageAfterConfirmation() {
        let repository = FakeOrderRepository()
        let updatedAt = Date(timeIntervalSince1970: 1_800_080_000)
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(
            id: "order-vanilla",
            recipeId: "recipe-vanilla",
            status: .confirmed,
            dueAt: dueAt
        )
        repository.orders = [original]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { updatedAt }
        )

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftStatus = .ready

        XCTAssertTrue(viewModel.saveEditedOrder(confirmingRecipeUsage: true))
        XCTAssertEqual(viewModel.selectedOrder?.status, .ready)
        XCTAssertEqual(
            viewModel.selectedOrderRecipeUsage,
            OrderRecipeUsage(
                id: "generated-1",
                orderId: original.id,
                recipeId: "recipe-vanilla",
                usedAt: updatedAt,
                createdAt: updatedAt,
                updatedAt: updatedAt
            )
        )
        XCTAssertEqual(repository.recordedTransactionIds, ["generated-2"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedOrderRefreshesLinkedCustomerDetails() {
        let repository = FakeOrderRepository()
        let dueAt = Date(timeIntervalSince1970: 1_800_140_000)
        let original = makeOrder(id: "order-vanilla", dueAt: dueAt)
        let customer = makeCustomer(id: "customer-zoe", name: "Zoe", allergies: "Sesame")
        repository.orders = [original]
        repository.customers = [customer]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(original)
        viewModel.beginEditingOrder()
        viewModel.draftCustomerId = "customer-zoe"
        viewModel.applySelectedCustomer()

        XCTAssertTrue(viewModel.saveEditedOrder())

        XCTAssertEqual(viewModel.selectedOrder?.customerId, "customer-zoe")
        XCTAssertEqual(viewModel.selectedOrder?.customerName, "Zoe")
        XCTAssertEqual(viewModel.selectedOrderCustomer, customer)
    }
}
