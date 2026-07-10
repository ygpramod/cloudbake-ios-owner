import Foundation

enum AppCurrency: String, CaseIterable, Equatable {
    case usDollar = "$"
    case indianRupee = "₹"
    case britishPound = "£"
    case malaysianRinggit = "RM"
    case singaporeDollar = "S$"

    static let defaultCurrency: AppCurrency = .usDollar

    var symbol: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .usDollar:
            return "$ US Dollar"
        case .indianRupee:
            return "₹ Indian Rupee"
        case .britishPound:
            return "£ British Pound"
        case .malaysianRinggit:
            return "RM Malaysian Ringgit"
        case .singaporeDollar:
            return "S$ Singapore Dollar"
        }
    }
}

enum AppSettings {
    static let currencySymbolKey = "cloudbake.currencySymbol"

    static var currency: AppCurrency {
        AppCurrency(rawValue: UserDefaults.standard.string(forKey: currencySymbolKey) ?? "")
            ?? AppCurrency.defaultCurrency
    }
}

enum MoneyDisplay {
    static func formatted(_ amount: Decimal, currency: AppCurrency = AppSettings.currency) -> String {
        "\(currency.symbol)\(NSDecimalNumber(decimal: amount).stringValue)"
    }
}

enum InventoryUnit: String, Equatable {
    case kilogram
    case gram
    case liter
    case milliliter
    case teaspoon
    case tablespoon
    case cup
    case each

    var compatibleUnits: [InventoryUnit] {
        switch measurementFamily {
        case .weight:
            return [.kilogram, .gram]
        case .volume:
            return [.liter, .milliliter, .teaspoon, .tablespoon, .cup]
        case .count:
            return [.each]
        }
    }

    func convertedQuantity(_ quantity: Double, to targetUnit: InventoryUnit) -> Double? {
        guard measurementFamily == targetUnit.measurementFamily else {
            return nil
        }

        switch measurementFamily {
        case .weight:
            guard let sourceGrams = gramsPerUnit, let targetGrams = targetUnit.gramsPerUnit else {
                return nil
            }
            return quantity * sourceGrams / targetGrams
        case .volume:
            guard let sourceMilliliters = millilitersPerUnit,
                  let targetMilliliters = targetUnit.millilitersPerUnit else {
                return nil
            }
            return quantity * sourceMilliliters / targetMilliliters
        case .count:
            return quantity
        }
    }

    private var measurementFamily: MeasurementFamily {
        switch self {
        case .kilogram, .gram:
            return .weight
        case .liter, .milliliter, .teaspoon, .tablespoon, .cup:
            return .volume
        case .each:
            return .count
        }
    }

    private var gramsPerUnit: Double? {
        switch self {
        case .kilogram:
            return 1_000
        case .gram:
            return 1
        case .liter, .milliliter, .teaspoon, .tablespoon, .cup, .each:
            return nil
        }
    }

    private var millilitersPerUnit: Double? {
        switch self {
        case .liter:
            return 1_000
        case .milliliter:
            return 1
        case .teaspoon:
            return 5
        case .tablespoon:
            return 15
        case .cup:
            return 240
        case .kilogram, .gram, .each:
            return nil
        }
    }
}

private enum MeasurementFamily {
    case weight
    case volume
    case count
}

enum InventoryItemType: String, Equatable, CaseIterable {
    case standard
    case perishable

    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .perishable:
            return "Perishable"
        }
    }
}

struct InventoryItem: Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let type: InventoryItemType
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
        aliases: [String] = [],
        type: InventoryItemType = .standard,
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
        self.aliases = aliases
        self.type = type
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

    func showsLowInventoryAlert(neededInventoryItemIds: Set<String>) -> Bool {
        guard isLowStock else {
            return false
        }

        switch type {
        case .standard:
            return true
        case .perishable:
            return neededInventoryItemIds.contains(id)
        }
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
    let amount: Decimal?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        inventoryItemId: String,
        remainingQuantity: Double,
        expiresAt: Date?,
        amount: Decimal? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.inventoryItemId = inventoryItemId
        self.remainingQuantity = remainingQuantity
        self.expiresAt = expiresAt
        self.amount = amount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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
    let name: String
    let phone: String
    let email: String?
    let address: String?
    let likes: String?
    let dislikes: String?
    let allergies: String?
    let dietaryRestrictions: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

struct CustomerImportantDate: Equatable {
    let id: String
    let customerId: String
    let label: String
    let date: Date
    let createdAt: Date
    let updatedAt: Date
}

enum OrderStatus: String, Equatable, CaseIterable {
    case draft
    case confirmed
    case inProgress
    case ready
    case completed
    case cancelled
}

enum OrderFulfillmentType: String, Equatable, CaseIterable {
    case pickup
    case delivery
}

struct Order: Equatable {
    let id: String
    let customerId: String?
    let cakeDesignId: String?
    let recipeId: String?
    let recipeScaleMultiplier: Decimal
    let title: String
    let customerName: String
    let status: OrderStatus
    let dueAt: Date
    let fulfillmentType: OrderFulfillmentType
    let deliveryAddress: String?
    let cakeNotes: String?
    let cakeMessage: String?
    let quotedPrice: Decimal?
    let depositPaid: Decimal?
    let paymentNotes: String?
    let createdAt: Date
    let updatedAt: Date

    var balanceDue: Decimal? {
        guard let quotedPrice else {
            return nil
        }

        return quotedPrice - (depositPaid ?? 0)
    }

    var paymentStatus: String {
        guard let quotedPrice else {
            return "Not Priced"
        }

        let paid = depositPaid ?? 0
        if paid <= 0 {
            return "Unpaid"
        }

        if paid >= quotedPrice {
            return "Paid"
        }

        return "Part Paid"
    }

    init(
        id: String,
        customerId: String?,
        cakeDesignId: String?,
        recipeId: String? = nil,
        recipeScaleMultiplier: Decimal = 1,
        title: String,
        customerName: String,
        status: OrderStatus,
        dueAt: Date,
        fulfillmentType: OrderFulfillmentType,
        deliveryAddress: String?,
        cakeNotes: String?,
        cakeMessage: String? = nil,
        quotedPrice: Decimal? = nil,
        depositPaid: Decimal? = nil,
        paymentNotes: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.customerId = customerId
        self.cakeDesignId = cakeDesignId
        self.recipeId = recipeId
        self.recipeScaleMultiplier = recipeScaleMultiplier
        self.title = title
        self.customerName = customerName
        self.status = status
        self.dueAt = dueAt
        self.fulfillmentType = fulfillmentType
        self.deliveryAddress = deliveryAddress
        self.cakeNotes = cakeNotes
        self.cakeMessage = cakeMessage
        self.quotedPrice = quotedPrice
        self.depositPaid = depositPaid
        self.paymentNotes = paymentNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct OrderRecipeUsage: Equatable {
    let id: String
    let orderId: String
    let recipeId: String
    let recipeScaleMultiplier: Decimal
    let usedAt: Date
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        orderId: String,
        recipeId: String,
        recipeScaleMultiplier: Decimal = 1,
        usedAt: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.orderId = orderId
        self.recipeId = recipeId
        self.recipeScaleMultiplier = recipeScaleMultiplier
        self.usedAt = usedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct OrderExtraIngredient: Equatable {
    let id: String
    let orderId: String
    let inventoryItemId: String
    let quantity: Double
    let unit: InventoryUnit
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}

struct OrderChecklistItem: Equatable {
    let id: String
    let orderId: String
    let title: String
    let isCompleted: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
}

enum OrderPhotoKind: String, Equatable, CaseIterable {
    case customerReference
    case finalCake
}

struct OrderPhoto: Equatable {
    let id: String
    let orderId: String
    let kind: OrderPhotoKind
    let localPhotoPath: String
    let caption: String?
    let createdAt: Date
    let updatedAt: Date
}

enum OrderRecipeUsageError: Error, Equatable {
    case orderHasNoLinkedRecipe
    case alreadyRecorded
    case recipeHasNoIngredients
    case missingInventoryItem(String)
    case incompatibleIngredientUnit(itemName: String)
    case insufficientStock(itemName: String)
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
