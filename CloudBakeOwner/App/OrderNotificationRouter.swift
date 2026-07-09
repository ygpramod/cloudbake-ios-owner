import Foundation
import UserNotifications

@MainActor
final class OrderNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var pendingOrderId: String?

    override init() {
        super.init()
    }

    func configureNotificationCenter(_ notificationCenter: UNUserNotificationCenter = .current()) {
        notificationCenter.delegate = self
    }

    func openOrder(id: String) {
        pendingOrderId = id
    }

    func consumePendingOrderId() -> String? {
        defer {
            pendingOrderId = nil
        }

        return pendingOrderId
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
