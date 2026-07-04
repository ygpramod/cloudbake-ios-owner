import Foundation

enum InventoryUnit: String, Equatable {
    case kilogram
    case gram
    case milliliter
    case teaspoon
    case tablespoon
    case cup
    case each
}

struct InventoryItem: Equatable {
    let id: String
    let name: String
    let unit: InventoryUnit
    let currentQuantity: Double
    let minimumQuantity: Double
    let earliestExpiryAt: Date?
    let hasExpiredStock: Bool
    let hasExpiringSoonStock: Bool
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    init(
        id: String,
        name: String,
        unit: InventoryUnit,
        currentQuantity: Double,
        minimumQuantity: Double,
        earliestExpiryAt: Date? = nil,
        hasExpiredStock: Bool = false,
        hasExpiringSoonStock: Bool = false,
        createdAt: Date,
        updatedAt: Date,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.currentQuantity = currentQuantity
        self.minimumQuantity = minimumQuantity
        self.earliestExpiryAt = earliestExpiryAt
        self.hasExpiredStock = hasExpiredStock
        self.hasExpiringSoonStock = hasExpiringSoonStock
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    var isLowStock: Bool {
        currentQuantity < minimumQuantity || hasExpiredStock || hasExpiringSoonStock
    }

    var isArchived: Bool {
        archivedAt != nil
    }
}

struct InventoryStockBatch: Equatable {
    let id: String
    let inventoryItemId: String
    let remainingQuantity: Double
    let expiresAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct Recipe: Equatable {
    let id: String
    let name: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct RecipeComponent: Equatable {
    let id: String
    let recipeId: String
    let name: String
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
}

struct RecipeIngredient: Equatable {
    let id: String
    let componentId: String
    let inventoryItemId: String
    let quantity: Double
    let unit: InventoryUnit
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

struct CakeDesign: Equatable {
    let id: String
    let name: String
    let notes: String?
    let photoReference: String?
    let createdAt: Date
    let updatedAt: Date
}

struct Customer: Equatable {
    let id: String
    let displayName: String
    let likes: String?
    let dislikes: String?
    let allergies: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

enum OrderStatus: String, Equatable {
    case draft
    case confirmed
    case completed
    case cancelled
}

struct Order: Equatable {
    let id: String
    let customerId: String?
    let cakeDesignId: String?
    let title: String
    let status: OrderStatus
    let dueAt: Date
    let createdAt: Date
    let updatedAt: Date
}

enum InventoryTransactionKind: String, Equatable {
    case adjustment
    case purchase
    case consumption
}

struct InventoryTransaction: Equatable {
    let id: String
    let inventoryItemId: String
    let kind: InventoryTransactionKind
    let quantity: Double
    let occurredAt: Date
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

enum PricingRuleKind: String, Equatable {
    case basePrice
    case labor
    case ingredientMarkup
    case designComplexity
}

struct PricingRule: Equatable {
    let id: String
    let name: String
    let kind: PricingRuleKind
    let amount: Decimal
    let currencyCode: String
    let createdAt: Date
    let updatedAt: Date
}
