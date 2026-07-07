import Foundation

struct OrderCalendarDay: Equatable {
    let day: Date
    let orders: [Order]
}

struct OrderReminderPlanItem: Equatable {
    let offsetDays: Int
    let remindAt: Date

    var title: String {
        "\(offsetDays) \(offsetDays == 1 ? "Day" : "Days") Before"
    }
}

struct OrderReminderDueGroup: Equatable {
    let order: Order
    let reminders: [OrderReminderPlanItem]

    var earliestRemindAt: Date? {
        reminders.map(\.remindAt).min()
    }
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

    func completedOrders(from orders: [Order]) -> [Order] {
        orders
            .filter(\.hasCompletedHistoryState)
            .sorted(by: Self.orderWasDueAfter)
    }

    func customerReferencePhotos(from photos: [OrderPhoto]) -> [OrderPhoto] {
        photos.filter { $0.kind == .customerReference }
    }

    func finalCakePhotos(from photos: [OrderPhoto]) -> [OrderPhoto] {
        photos.filter { $0.kind == .finalCake }
    }

    func dueReminderGroups(for orders: [Order]) -> [OrderReminderDueGroup] {
        let now = dateProvider()
        return orders
            .filter(\.hasActiveReminderState)
            .compactMap { order in
                let dueReminders = reminderPlan(for: order)
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

    func reminderPlan(for order: Order) -> [OrderReminderPlanItem] {
        [3, 2, 1].compactMap { offsetDays in
            guard let remindAt = calendar.date(byAdding: .day, value: -offsetDays, to: order.dueAt) else {
                return nil
            }

            return OrderReminderPlanItem(offsetDays: offsetDays, remindAt: remindAt)
        }
    }

    func nextReminder(for order: Order) -> OrderReminderPlanItem? {
        let now = dateProvider()
        let reminders = reminderPlan(for: order)
        return reminders.first { $0.remindAt > now } ?? reminders.last
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

    private static func orderWasEnteredBefore(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.id < rhs.id
        }

        return lhs.createdAt < rhs.createdAt
    }

    private static func orderIsDueBefore(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            return orderWasEnteredBefore(lhs, rhs)
        }

        return lhs.dueAt < rhs.dueAt
    }

    private static func orderWasDueAfter(_ lhs: Order, _ rhs: Order) -> Bool {
        if lhs.dueAt == rhs.dueAt {
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }

            return lhs.createdAt > rhs.createdAt
        }

        return lhs.dueAt > rhs.dueAt
    }
}
