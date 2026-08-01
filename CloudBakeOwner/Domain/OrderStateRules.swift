import Foundation

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

enum OrderDueDateDefaults {
    static func dueAt(after creationDate: Date, calendar: Calendar) -> Date {
        let hourStart =
            calendar.dateInterval(of: .hour, for: creationDate)?.start
            ?? creationDate
        let roundedHour: Date
        if creationDate.timeIntervalSince(hourStart) < 30 * 60 {
            roundedHour = hourStart
        } else {
            roundedHour =
                calendar.date(byAdding: .hour, value: 1, to: hourStart)
                ?? hourStart.addingTimeInterval(60 * 60)
        }

        return calendar.date(byAdding: .day, value: 1, to: roundedHour)
            ?? roundedHour.addingTimeInterval(24 * 60 * 60)
    }
}
