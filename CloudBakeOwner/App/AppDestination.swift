import Foundation

enum AppDestination: String, CaseIterable, Hashable, Identifiable {
    case dashboard
    case orders
    case inventory
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
}
