import Foundation
import UserNotifications

@MainActor
final class OrderNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var pendingOrderId: String?

    override init() {
        super.init()
        configureNotificationCenter()
    }

    func configureNotificationCenter(_ notificationCenter: UNUserNotificationCenter = .current()) {
        notificationCenter.delegate = self
    }

    func openOrder(id: String) {
        pendingOrderId = id
    }

    func clearPendingOrderId() {
        pendingOrderId = nil
    }

    func routeNotification(userInfo: [AnyHashable: Any]) {
        guard userInfo[OrderReminderScheduler.orderNotificationDestinationKey] as? String == OrderReminderScheduler.orderNotificationDestinationOrder,
              let orderId = userInfo[OrderReminderScheduler.orderNotificationOrderIdKey] as? String else {
            return
        }

        openOrder(id: orderId)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo[OrderReminderScheduler.orderNotificationDestinationKey] as? String == OrderReminderScheduler.orderNotificationDestinationOrder,
              let orderId = userInfo[OrderReminderScheduler.orderNotificationOrderIdKey] as? String else {
            return
        }

        await MainActor.run {
            openOrder(id: orderId)
        }
    }
}
