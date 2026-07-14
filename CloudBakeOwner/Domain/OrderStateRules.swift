extension Order {
    var hasActiveReminderState: Bool {
        status != .completed && status != .cancelled
    }

    var hasCompletedHistoryState: Bool {
        status == .completed || status == .cancelled
    }

    var hasScheduledReminderState: Bool {
        status == .confirmed || status == .inProgress || status == .ready
    }
}

extension OrderStatus {
    func recordsRecipeUsage(whenChangingTo newStatus: OrderStatus) -> Bool {
        self != newStatus && (newStatus == .ready || newStatus == .completed)
    }
}
