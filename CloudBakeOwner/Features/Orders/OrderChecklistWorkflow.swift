import Foundation

struct OrderChecklistWorkflowError: Error, Equatable {
    let ownerMessage: String
}

struct OrderChecklistWorkflow {
    private let repository: any OrderChecklistRepository
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    init(
        repository: any OrderChecklistRepository,
        idGenerator: @escaping () -> String,
        dateProvider: @escaping () -> Date
    ) {
        self.repository = repository
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func load(orderId: String) -> Result<[OrderChecklistItem], OrderChecklistWorkflowError> {
        do {
            return .success(
                try repository.fetchOrderChecklistItems(orderId: orderId)
                    .sorted(by: OrderListPresentation.checklistItemWasEnteredBefore)
            )
        } catch {
            return .failure(
                OrderChecklistWorkflowError(
                    ownerMessage: "Checklist could not be loaded."
                )
            )
        }
    }

    func add(
        to order: Order,
        title: String,
        existingItems: [OrderChecklistItem]
    ) -> Result<Void, OrderChecklistWorkflowError> {
        let trimmedTitle = TextInputFormatting.trimmed(title)
        guard !trimmedTitle.isEmpty else {
            return .failure(
                OrderChecklistWorkflowError(
                    ownerMessage: "Checklist item is required."
                )
            )
        }

        let now = dateProvider()
        let nextSortOrder = (existingItems.map(\.sortOrder).max() ?? -1) + 1
        let item = OrderChecklistItem(
            id: idGenerator(),
            orderId: order.id,
            title: trimmedTitle,
            isCompleted: false,
            sortOrder: nextSortOrder,
            createdAt: now,
            updatedAt: now
        )
        return save(
            item,
            failureMessage: "Checklist item could not be saved."
        )
    }

    func toggle(_ item: OrderChecklistItem) -> Result<Void, OrderChecklistWorkflowError> {
        save(
            OrderChecklistItem(
                id: item.id,
                orderId: item.orderId,
                title: item.title,
                isCompleted: !item.isCompleted,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                updatedAt: dateProvider()
            ),
            failureMessage: "Checklist item could not be updated."
        )
    }

    func updateTitle(
        of item: OrderChecklistItem,
        to title: String
    ) -> Result<Void, OrderChecklistWorkflowError> {
        let trimmedTitle = TextInputFormatting.trimmed(title)
        guard !trimmedTitle.isEmpty else {
            return .failure(
                OrderChecklistWorkflowError(
                    ownerMessage: "Checklist item is required."
                )
            )
        }

        return save(
            OrderChecklistItem(
                id: item.id,
                orderId: item.orderId,
                title: trimmedTitle,
                isCompleted: item.isCompleted,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                updatedAt: dateProvider()
            ),
            failureMessage: "Checklist item could not be updated."
        )
    }

    func delete(_ item: OrderChecklistItem) -> Result<Void, OrderChecklistWorkflowError> {
        do {
            try repository.deleteOrderChecklistItem(id: item.id)
            return .success(())
        } catch {
            return .failure(
                OrderChecklistWorkflowError(
                    ownerMessage: "Checklist item could not be deleted."
                )
            )
        }
    }

    private func save(
        _ item: OrderChecklistItem,
        failureMessage: String
    ) -> Result<Void, OrderChecklistWorkflowError> {
        do {
            try repository.save(item)
            return .success(())
        } catch {
            return .failure(
                OrderChecklistWorkflowError(ownerMessage: failureMessage)
            )
        }
    }
}
