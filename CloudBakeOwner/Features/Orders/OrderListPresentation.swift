import Foundation

struct OrderCalendarDay: Equatable {
    let day: Date
    let orders: [Order]
}

struct OrderReminderPlanItem: Equatable {
    let offsetDays: Int
    let remindAt: Date

    var title: String {
        if offsetDays == 0 {
            return "Due Time"
        }
        return "\(offsetDays) \(offsetDays == 1 ? "Day" : "Days") Before"
    }
}

struct OrderReminderDueGroup: Equatable {
    let order: Order
    let reminders: [OrderReminderPlanItem]

    var earliestRemindAt: Date? {
        reminders.map(\.remindAt).min()
    }
}

struct OrderOverdueAlert: Equatable {
    let order: Order
    let message: String
}

struct OrderListPresentation {
    let dateProvider: () -> Date
    let calendar: Calendar

    func calendarDays(for orders: [Order]) -> [OrderCalendarDay] {
        let groupedOrders = Dictionary(grouping: activeOrders(from: orders)) { order in
            calendar.startOfDay(for: order.dueAt)
        }

        return groupedOrders.keys.sorted().map { day in
            OrderCalendarDay(
                day: day,
                orders: groupedOrders[day, default: []].sorted(by: Self.orderIsDueBefore)
            )
        }
    }

    func activeOrders(from orders: [Order]) -> [Order] {
        orders
            .filter(\.hasActiveReminderState)
            .sorted(by: Self.orderIsDueBefore)
    }

    func upcomingOrders(from orders: [Order], throughDays: Int = 30) -> [Order] {
        guard let range = upcomingDateRange(throughDays: throughDays) else {
            return []
        }

        return activeOrders(from: orders).filter { order in
            range.contains(order.dueAt)
        }
    }

    func upcomingDateRange(throughDays: Int = 30) -> ClosedRange<Date>? {
        let today = calendar.startOfDay(for: dateProvider())
        guard let exclusiveEnd = calendar.date(
            byAdding: .day,
            value: throughDays + 1,
            to: today
        ) else {
            return nil
        }
        return today...exclusiveEnd.addingTimeInterval(-0.001)
    }

    func completedOrders(from orders: [Order]) -> [Order] {
        orders
            .filter(\.hasCompletedHistoryState)
            .sorted(by: Self.orderWasDueAfter)
    }

    func overdueOrders(from orders: [Order]) -> [Order] {
        let now = dateProvider()
        return activeOrders(from: orders)
            .filter { $0.dueAt < now }
    }

    func isOverdue(_ order: Order) -> Bool {
        order.hasActiveReminderState && order.dueAt < dateProvider()
    }

    func primaryOverdueAlert(from orders: [Order]) -> OrderOverdueAlert? {
        guard let order = overdueOrders(from: orders).first else {
            return nil
        }

        return OrderOverdueAlert(
            order: order,
            message: overdueMessage(for: order)
        )
    }

    func customerReferencePhotos(from photos: [OrderPhoto]) -> [OrderPhoto] {
        photos.filter { $0.kind == .customerReference }
    }

    func finalCakePhotos(from photos: [OrderPhoto]) -> [OrderPhoto] {
        photos.filter { $0.kind == .finalCake }
    }

    func dueReminderGroups(
        for orders: [Order],
        configurations: [String: OrderReminderConfiguration]
    ) -> [OrderReminderDueGroup] {
        let now = dateProvider()
        return orders
            .filter(\.hasActiveReminderState)
            .compactMap { order in
                let dueReminders = reminderPlan(
                    for: order,
                    configuration: configurations[order.id] ?? .initialDefault
                )
                    .filter { $0.remindAt <= now }

                guard !dueReminders.isEmpty else {
                    return nil
                }

                guard let nextDueReminder = dueReminders.max(by: { $0.remindAt < $1.remindAt }) else {
                    return nil
                }

                return OrderReminderDueGroup(order: order, reminders: [nextDueReminder])
            }
            .sorted { lhs, rhs in
                if lhs.earliestRemindAt == rhs.earliestRemindAt {
                    if lhs.order.dueAt == rhs.order.dueAt {
                        return lhs.order.title < rhs.order.title
                    }

                    return lhs.order.dueAt < rhs.order.dueAt
                }

                return (lhs.earliestRemindAt ?? lhs.order.dueAt) < (rhs.earliestRemindAt ?? rhs.order.dueAt)
            }
    }

    func reminderPlan(
        for order: Order,
        configuration: OrderReminderConfiguration
    ) -> [OrderReminderPlanItem] {
        guard configuration.isEnabled else {
            return []
        }
        let offsets = configuration.dayOffsets
            + (configuration.includesDueTime ? [0] : [])
        return offsets.compactMap { offsetDays in
            guard let remindAt = calendar.date(byAdding: .day, value: -offsetDays, to: order.dueAt) else {
                return nil
            }

            return OrderReminderPlanItem(offsetDays: offsetDays, remindAt: remindAt)
        }
    }

    func nextReminder(
        for order: Order,
        configuration: OrderReminderConfiguration
    ) -> OrderReminderPlanItem? {
        let now = dateProvider()
        let reminders = reminderPlan(for: order, configuration: configuration)
        return reminders.first { $0.remindAt > now } ?? reminders.last
    }

    private func overdueMessage(for order: Order) -> String {
        let now = dateProvider()
        if calendar.isDate(order.dueAt, inSameDayAs: now) {
            return "\(order.title) was due at \(order.dueAt.formatted(date: .omitted, time: .shortened)), update status?"
        }

        return "\(order.title) is overdue. Update status?"
    }

    static func checklistItemWasEnteredBefore(_ lhs: OrderChecklistItem, _ rhs: OrderChecklistItem) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }

            return lhs.createdAt < rhs.createdAt
        }

        return lhs.sortOrder < rhs.sortOrder
    }

    private static func orderIsDueBefore(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            return lhs.id < rhs.id
        }

        return lhs.dueAt < rhs.dueAt
    }

    private static func orderWasDueAfter(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            return lhs.id > rhs.id
        }

        return lhs.dueAt > rhs.dueAt
    }
}
