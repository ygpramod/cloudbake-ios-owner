import XCTest
@testable import CloudBakeOwner

final class ProjectedIngredientDemandTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAggregatesScaledRecipeAndExtraDemandAcrossActiveOrders() throws {
        let item = makeItem(quantity: 800)
        let orders = [
            makeDemandOrder(id: "order-1", scale: 2),
            makeDemandOrder(id: "order-2", scale: 1)
        ]
        let shortages = try shortages(
            item: item,
            orders: orders,
            recipeQuantity: 250,
            extras: [
                "order-1": [makeExtra(orderId: "order-1", quantity: 100)]
            ]
        )

        XCTAssertEqual(shortages.count, 1)
        XCTAssertEqual(shortages[0].requiredQuantity, 850, accuracy: 0.001)
        XCTAssertEqual(shortages[0].availableQuantity, 800, accuracy: 0.001)
        XCTAssertEqual(shortages[0].orderIds, ["order-1", "order-2"])
    }

    func testExcludesCompletedCancelledAndAlreadyConsumedOrders() throws {
        let item = makeItem(quantity: 100)
        let orders = [
            makeDemandOrder(id: "active", scale: 1),
            makeDemandOrder(id: "completed", status: .completed, scale: 1),
            makeDemandOrder(id: "cancelled", status: .cancelled, scale: 1),
            makeDemandOrder(id: "consumed", scale: 1)
        ]
        let shortages = try shortages(
            item: item,
            orders: orders,
            consumedOrderIds: ["consumed"],
            recipeQuantity: 150
        )

        XCTAssertEqual(shortages.count, 1)
        XCTAssertEqual(shortages[0].requiredQuantity, 150, accuracy: 0.001)
        XCTAssertEqual(shortages[0].orderIds, ["active"])
    }

    func testAvailabilityExcludesExpiredBatches() throws {
        let item = makeItem(quantity: 500)
        let batches = [
            makeBatch(id: "expired", quantity: 400, expiresAt: now.addingTimeInterval(-1)),
            makeBatch(id: "usable", quantity: 100, expiresAt: now.addingTimeInterval(86_400))
        ]
        let shortages = try shortages(
            item: item,
            orders: [makeDemandOrder(id: "order", scale: 1)],
            batches: batches,
            recipeQuantity: 150
        )

        XCTAssertEqual(shortages.count, 1)
        XCTAssertEqual(shortages[0].availableQuantity, 100, accuracy: 0.001)
        XCTAssertEqual(shortages[0].missingQuantity, 50, accuracy: 0.001)
    }

    private func shortages(
        item: InventoryItem,
        orders: [Order],
        consumedOrderIds: Set<String> = [],
        batches: [InventoryStockBatch] = [],
        recipeQuantity: Double,
        extras: [String: [OrderExtraIngredient]] = [:]
    ) throws -> [ProjectedIngredientShortage] {
        let component = RecipeComponent(
            id: "component",
            recipeId: "recipe",
            name: "Cake",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )
        let ingredient = RecipeIngredient(
            id: "ingredient",
            componentId: component.id,
            inventoryItemId: item.id,
            quantity: recipeQuantity,
            unit: .gram,
            note: nil,
            createdAt: now,
            updatedAt: now
        )

        return try ProjectedIngredientDemand.shortages(
            inventoryItems: [item],
            orders: orders,
            at: now,
            stockBatches: { _ in batches },
            recipeUsage: { orderId in
                guard consumedOrderIds.contains(orderId) else { return nil }
                return OrderRecipeUsage(
                    id: "usage-\(orderId)",
                    orderId: orderId,
                    recipeId: "recipe",
                    usedAt: now,
                    createdAt: now,
                    updatedAt: now
                )
            },
            recipeComponents: { _ in [component] },
            recipeIngredients: { _ in [ingredient] },
            orderExtraIngredients: { extras[$0] ?? [] }
        )
    }

    private func makeItem(quantity: Double) -> InventoryItem {
        InventoryItem(
            id: "flour",
            name: "Cake flour",
            unit: .gram,
            currentQuantity: quantity,
            minimumQuantity: 50,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeBatch(id: String, quantity: Double, expiresAt: Date) -> InventoryStockBatch {
        InventoryStockBatch(
            id: id,
            inventoryItemId: "flour",
            remainingQuantity: quantity,
            expiresAt: expiresAt,
            amount: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeDemandOrder(
        id: String,
        status: OrderStatus = .confirmed,
        scale: Decimal
    ) -> Order {
        Order(
            id: id,
            customerId: nil,
            cakeDesignId: nil,
            recipeId: "recipe",
            recipeScaleMultiplier: scale,
            title: id,
            customerName: "Amy",
            status: status,
            dueAt: now,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeExtra(orderId: String, quantity: Double) -> OrderExtraIngredient {
        OrderExtraIngredient(
            id: "extra-\(orderId)",
            orderId: orderId,
            inventoryItemId: "flour",
            quantity: quantity,
            unit: .gram,
            note: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
