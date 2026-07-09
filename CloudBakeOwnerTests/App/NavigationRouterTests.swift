import XCTest
@testable import CloudBakeOwner

@MainActor
final class NavigationRouterTests: XCTestCase {
    func testOrderNotificationRouterRoutesOrderNotificationPayload() {
        let router = OrderNotificationRouter()

        router.routeNotification(userInfo: [
            OrderReminderScheduler.orderNotificationDestinationKey: OrderReminderScheduler.orderNotificationDestinationOrder,
            OrderReminderScheduler.orderNotificationOrderIdKey: "order-chocolate"
        ])

        XCTAssertEqual(router.pendingOrderId, "order-chocolate")
    }

    func testOrderNotificationRouterIgnoresUnknownPayload() {
        let router = OrderNotificationRouter()

        router.routeNotification(userInfo: [
            OrderReminderScheduler.orderNotificationDestinationKey: "customer",
            OrderReminderScheduler.orderNotificationOrderIdKey: "order-chocolate"
        ])

        XCTAssertNil(router.pendingOrderId)
    }

    func testOrderNotificationRouterClearsPendingOrderOnlyWhenAsked() {
        let router = OrderNotificationRouter()
        router.openOrder(id: "order-chocolate")

        XCTAssertEqual(router.pendingOrderId, "order-chocolate")

        router.clearPendingOrderId()

        XCTAssertNil(router.pendingOrderId)
    }

    func testInventoryNavigationRouterClearsPendingItemOnlyWhenAsked() {
        let router = InventoryNavigationRouter()
        router.openInventoryItem(id: "inventory-flour")

        XCTAssertEqual(router.pendingInventoryItemId, "inventory-flour")

        router.clearPendingInventoryItemId()

        XCTAssertNil(router.pendingInventoryItemId)
    }
}
