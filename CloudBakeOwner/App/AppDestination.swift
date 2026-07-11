import Foundation

enum AppDestination: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case orders
    case inventory
    case more
    case recipes
    case designs
    case reminders
    case customers
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .orders: "Orders"
        case .inventory: "Inventory"
        case .more: "More"
        case .recipes: "Recipes"
        case .designs: "Designs"
        case .reminders: "Reminders"
        case .customers: "Customers"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .orders: "calendar"
        case .inventory: "shippingbox"
        case .more: "ellipsis.circle"
        case .recipes: "book"
        case .designs: "photo.on.rectangle"
        case .reminders: "bell"
        case .customers: "person.2"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "navigation.\(rawValue)"
    }

    var screenAccessibilityIdentifier: String {
        "screen.\(rawValue)"
    }

    var isGroupedUnderMore: Bool {
        switch self {
        case .recipes, .designs, .reminders, .customers, .settings:
            return true
        case .dashboard, .orders, .inventory, .more:
            return false
        }
    }
}
