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
