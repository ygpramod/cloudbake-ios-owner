import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderChecklistViewModelTests: XCTestCase {
    func testBeginViewingOrderLoadsChecklistItems() {
        let repository = FakeOrderRepository()
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let checklistItem = makeChecklistItem(id: "checklist-crumb-coat", orderId: order.id, title: "Crumb coat")
        repository.checklistItems = [checklistItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertEqual(viewModel.selectedOrderChecklistItems, [checklistItem])
    }

    func testAddChecklistItemToSelectedOrderPersistsTrimmedTitle() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        repository.checklistItems = [
            makeChecklistItem(id: "checklist-existing", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        ]
        let viewModel = OrderListViewModel(
            repository: repository,
            idGenerator: { "checklist-crumb-coat" },
            dateProvider: { now }
        )

        viewModel.beginViewingOrder(order)
        viewModel.draftChecklistItemTitle = " Crumb coat "

        XCTAssertTrue(viewModel.addChecklistItemToSelectedOrder())
        XCTAssertEqual(viewModel.draftChecklistItemTitle, "")
        XCTAssertEqual(
            repository.checklistItems.last,
            OrderChecklistItem(
                id: "checklist-crumb-coat",
                orderId: order.id,
                title: "Crumb coat",
                isCompleted: false,
                sortOrder: 1,
                createdAt: now,
                updatedAt: now
            )
        )
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.map(\.title), ["Bake sponge", "Crumb coat"])
    }

    func testToggleChecklistItemUpdatesCompletionState() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let checklistItem = makeChecklistItem(id: "checklist-bake", orderId: order.id, title: "Bake sponge")
        repository.checklistItems = [checklistItem]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.toggleChecklistItem(checklistItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.isCompleted, true)
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.updatedAt, now)
    }

    func testToggleChecklistItemPreservesEntryOrder() {
        let repository = FakeOrderRepository()
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let firstItem = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        let secondItem = makeChecklistItem(id: "checklist-second", orderId: order.id, title: "Crumb coat", sortOrder: 1)
        repository.checklistItems = [secondItem, firstItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.toggleChecklistItem(firstItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.map(\.id), ["checklist-first", "checklist-second"])
    }

    func testUpdateChecklistItemTitlePersistsTrimmedTitleAndPreservesState() {
        let repository = FakeOrderRepository()
        let now = Date(timeIntervalSince1970: 1_800_080_000)
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let item = makeChecklistItem(
            id: "checklist-first",
            orderId: order.id,
            title: "Crumb coat",
            isCompleted: true,
            sortOrder: 2
        )
        repository.checklistItems = [item]
        let viewModel = OrderListViewModel(repository: repository, dateProvider: { now })

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.updateChecklistItemTitle(item, title: "  Final photo  "))
        XCTAssertEqual(repository.checklistItems.first?.title, "Final photo")
        XCTAssertEqual(repository.checklistItems.first?.isCompleted, true)
        XCTAssertEqual(repository.checklistItems.first?.sortOrder, 2)
        XCTAssertEqual(repository.checklistItems.first?.createdAt, item.createdAt)
        XCTAssertEqual(repository.checklistItems.first?.updatedAt, now)
        XCTAssertEqual(viewModel.selectedOrderChecklistItems.first?.title, "Final photo")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateChecklistItemTitleRejectsBlankTitle() {
        let repository = FakeOrderRepository()
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let item = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Crumb coat")
        repository.checklistItems = [item]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertFalse(viewModel.updateChecklistItemTitle(item, title: "   "))
        XCTAssertEqual(repository.checklistItems.first?.title, "Crumb coat")
        XCTAssertEqual(viewModel.errorMessage, "Checklist item is required.")
    }

    func testDeleteChecklistItemRemovesItFromSelectedOrder() {
        let repository = FakeOrderRepository()
        let order = makeChecklistOrder(id: "order-vanilla", dueAt: Date(timeIntervalSince1970: 1_800_140_000))
        let firstItem = makeChecklistItem(id: "checklist-first", orderId: order.id, title: "Bake sponge", sortOrder: 0)
        let secondItem = makeChecklistItem(id: "checklist-second", orderId: order.id, title: "Crumb coat", sortOrder: 1)
        repository.checklistItems = [firstItem, secondItem]
        let viewModel = OrderListViewModel(repository: repository)

        viewModel.beginViewingOrder(order)

        XCTAssertTrue(viewModel.deleteChecklistItem(firstItem))
        XCTAssertEqual(viewModel.selectedOrderChecklistItems, [secondItem])
        XCTAssertEqual(repository.checklistItems, [secondItem])
    }
}

private func makeChecklistOrder(
    id: String,
    dueAt: Date,
    createdAt: Date = Date(timeIntervalSince1970: 1_800_060_000)
) -> Order {
    return Order(
        id: id,
        customerId: nil,
        cakeDesignId: nil,
        recipeId: nil,
        title: "Vanilla Birthday",
        customerName: "Amy",
        status: .draft,
        dueAt: dueAt,
        fulfillmentType: .pickup,
        deliveryAddress: nil,
        cakeNotes: nil,
        quotedPrice: nil,
        depositPaid: nil,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

private func makeChecklistItem(
    id: String,
    orderId: String,
    title: String,
    isCompleted: Bool = false,
    sortOrder: Int = 0
) -> OrderChecklistItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return OrderChecklistItem(
        id: id,
        orderId: orderId,
        title: title,
        isCompleted: isCompleted,
        sortOrder: sortOrder,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}
