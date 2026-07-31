import Foundation
import UserNotifications

@MainActor
final class OrderNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var pendingOrderId: String?
    @Published private(set) var isPaymentReportPending = false

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

    func openPaymentReport() {
        isPaymentReportPending = true
    }

    func clearPendingPaymentReport() {
        isPaymentReportPending = false
    }

    func routeNotification(userInfo: [AnyHashable: Any]) {
        if userInfo[PaymentPendingReminderScheduler.notificationDestinationKey] as? String
            == PaymentPendingReminderScheduler.notificationDestination {
            openPaymentReport()
            return
        }
        guard userInfo[OrderReminderScheduler.orderNotificationDestinationKey] as? String == OrderReminderScheduler.orderNotificationDestinationOrder,
              let orderId = userInfo[OrderReminderScheduler.orderNotificationOrderIdKey] as? String else {
            return
        }

        openOrder(id: orderId)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(
            userInfo: response.notification.request.content.userInfo,
            completionHandler: completionHandler
        )
    }

    nonisolated func handleNotificationResponse(
        userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
        Task { @MainActor [weak self] in
            self?.routeNotification(userInfo: userInfo)
        }
    }
}
