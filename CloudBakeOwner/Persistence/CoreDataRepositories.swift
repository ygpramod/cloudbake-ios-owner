import Foundation

protocol InventoryItemRepository {
    func save(_ item: InventoryItem) throws
    func deleteInventoryItem(id: String) throws
    func fetchInventoryItem(id: String) throws -> InventoryItem?
    func fetchInventoryItems() throws -> [InventoryItem]
    func fetchArchivedInventoryItems() throws -> [InventoryItem]
}

enum InventoryItemDeletionError: Error, Equatable {
    case inUse
}

extension InventoryItemRepository {
    func deleteInventoryItem(id _: String) throws {
        throw InventoryItemDeletionError.inUse
    }
}

protocol RecipeRepository {
    func save(_ recipe: Recipe) throws
    func fetchRecipe(id: String) throws -> Recipe?
    func fetchRecipes() throws -> [Recipe]
}

protocol RecipeComponentRepository {
    func save(_ component: RecipeComponent) throws
    func fetchRecipeComponent(id: String) throws -> RecipeComponent?
    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent]
}

protocol RecipeIngredientRepository {
    func save(_ ingredient: RecipeIngredient) throws
    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient?
    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient]
    func deleteRecipeIngredient(id: String) throws
}

protocol RecipeIngredientReservationMutationRepository {
    func saveRecipeIngredient(
        _ ingredient: RecipeIngredient,
        component: RecipeComponent,
        allowInventoryShortage: Bool
    ) throws
    func deleteRecipeIngredient(
        id: String,
        updatedAt: Date,
        allowInventoryShortage: Bool
    ) throws
}

enum RecipeIngredientReservationMutationError: Error, Equatable {
    case componentNotFound
    case recipeReassignmentNotAllowed
}

protocol RecipeCSVImportRepository {
    func saveRecipeCSVImport(
        recipes: [Recipe],
        components: [RecipeComponent],
        ingredients: [RecipeIngredient]
    ) throws
}

protocol CakeDesignRepository {
    func save(_ design: CakeDesign) throws
    func deleteCakeDesign(id: String) throws
    func savePromotedDesign(
        _ design: CakeDesign,
        linking order: Order,
        photo: OrderPhoto,
        cleanupRelativePath: String?
    ) throws
    func fetchPendingDesignPhotoCleanupPaths() throws -> [String]
    func deletePendingDesignPhotoCleanupPath(_ relativePath: String) throws
    func fetchCakeDesign(id: String) throws -> CakeDesign?
    func fetchCakeDesign(originatingOrderPhotoId: String) throws -> CakeDesign?
    func fetchCakeDesigns() throws -> [CakeDesign]
    func fetchCakeDesigns(sourceKind: CakeDesignSourceKind) throws -> [CakeDesign]
}

enum CakeDesignPromotionError: Error, Equatable {
    case originatingPhotoAlreadyPromoted
}

enum OrderPersistenceError: Error, Equatable {
    case invalidCustomerReferencePhoto
    case multipleDesignReferences
}

extension CakeDesignRepository {
    func fetchCakeDesigns(sourceKind: CakeDesignSourceKind) throws -> [CakeDesign] {
        try fetchCakeDesigns().filter { $0.sourceKind == sourceKind }
    }
}

protocol CustomerRepository {
    func save(_ customer: Customer) throws
    func fetchCustomer(id: String) throws -> Customer?
    func fetchCustomers() throws -> [Customer]
    func deleteCustomer(id: String) throws
}

protocol CustomerImportantDateRepository {
    func save(_ importantDate: CustomerImportantDate) throws
    func fetchCustomerImportantDates(customerId: String) throws -> [CustomerImportantDate]
}

protocol OrderRepository {
    func save(_ order: Order) throws
    func fetchOrder(id: String) throws -> Order?
    func fetchOrders() throws -> [Order]
    func fetchOrderPage(
        query: OrderPageQuery,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> OrderPage
    func fetchOrderCount(query: OrderPageQuery) throws -> Int
}

struct CakeDesignOrderUsageSummary: Equatable {
    static let empty = CakeDesignOrderUsageSummary(
        countsByDesignId: [:],
        recentOrdersByDesignId: [:]
    )

    let countsByDesignId: [String: Int]
    let recentOrdersByDesignId: [String: [Order]]
}

enum CakeDesignOrderUsageQueryError: Error, Equatable {
    case invalidRecentOrderLimit
}

protocol CakeDesignOrderUsageRepository {
    func fetchCakeDesignOrderUsageSummary(
        recentOrderLimitPerDesign: Int
    ) throws -> CakeDesignOrderUsageSummary
}

extension CakeDesignOrderUsageRepository where Self: OrderRepository {
    func fetchCakeDesignOrderUsageSummary(
        recentOrderLimitPerDesign: Int
    ) throws -> CakeDesignOrderUsageSummary {
        guard (1...25).contains(recentOrderLimitPerDesign) else {
            throw CakeDesignOrderUsageQueryError.invalidRecentOrderLimit
        }
        let linkedOrders = try fetchOrders().filter { $0.cakeDesignId != nil }
        let grouped = Dictionary(grouping: linkedOrders) {
            $0.cakeDesignId ?? ""
        }
        return CakeDesignOrderUsageSummary(
            countsByDesignId: grouped.mapValues(\.count),
            recentOrdersByDesignId: grouped.mapValues {
                Array(
                    $0.sorted { lhs, rhs in
                        if lhs.dueAt != rhs.dueAt {
                            return lhs.dueAt > rhs.dueAt
                        }
                        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(
                            rhs.title
                        )
                        if titleOrder != .orderedSame {
                            return titleOrder == .orderedAscending
                        }
                        return lhs.id < rhs.id
                    }
                    .prefix(recentOrderLimitPerDesign)
                )
            }
        )
    }
}

enum OrderPageQuery: Equatable {
    case active(dueAtRange: ClosedRange<Date>?)
    case completed
    case upcoming(from: Date, through: Date)
    case customer(id: String)
    case paymentPending(asOf: Date)

    var isDescending: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    func validate() throws {
        if case .upcoming(let from, let through) = self, from > through {
            throw OrderPageQueryError.invalidDateRange
        }
    }

    func includes(_ order: Order) -> Bool {
        switch self {
        case .active(let range):
            return order.hasActiveReminderState
                && (range?.contains(order.dueAt) ?? true)
        case .completed:
            return order.status == .completed || order.status == .cancelled
        case .upcoming(let from, let through):
            return order.hasActiveReminderState
                && order.dueAt >= from
                && order.dueAt <= through
        case .customer(let customerId):
            return order.customerId == customerId
        case .paymentPending(let date):
            return order.hasPaymentPending(at: date)
        }
    }
}

struct OrderPageCursor: Equatable {
    let dueAt: Date
    let orderId: String
}

struct OrderPage: Equatable {
    let orders: [Order]
    let nextCursor: OrderPageCursor?
}

enum OrderPageQueryError: Error, Equatable {
    case invalidLimit
    case invalidDateRange
}

extension OrderRepository {
    func fetchOrderPage(
        query: OrderPageQuery,
        after cursor: OrderPageCursor?,
        limit: Int
    ) throws -> OrderPage {
        guard (1...50).contains(limit) else {
            throw OrderPageQueryError.invalidLimit
        }
        try query.validate()

        let filtered = try fetchOrders()
            .filter(query.includes)
            .sorted { lhs, rhs in
                if lhs.dueAt == rhs.dueAt {
                    return query.isDescending ? lhs.id > rhs.id : lhs.id < rhs.id
                }
                return query.isDescending ? lhs.dueAt > rhs.dueAt : lhs.dueAt < rhs.dueAt
            }
            .filter { order in
                guard let cursor else {
                    return true
                }
                if order.dueAt == cursor.dueAt {
                    return query.isDescending
                        ? order.id < cursor.orderId
                        : order.id > cursor.orderId
                }
                return query.isDescending
                    ? order.dueAt < cursor.dueAt
                    : order.dueAt > cursor.dueAt
            }

        let candidates = Array(filtered.prefix(limit + 1))
        let pageOrders = Array(candidates.prefix(limit))
        let nextCursor =
            candidates.count > limit
            ? pageOrders.last.map {
                OrderPageCursor(dueAt: $0.dueAt, orderId: $0.id)
            }
            : nil
        return OrderPage(orders: pageOrders, nextCursor: nextCursor)
    }

    func fetchOrderCount(query: OrderPageQuery) throws -> Int {
        try query.validate()
        return try fetchOrders().filter(query.includes).count
    }
}

protocol OrderReminderConfigurationRepository {
    func fetchDefaultOrderReminderConfiguration() throws -> OrderReminderConfiguration
    func saveDefaultOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        updatedAt: Date
    ) throws
    func fetchOrderReminderConfiguration(orderId: String) throws -> OrderReminderConfiguration?
    func fetchOrderReminderConfigurations(
        orderIds: [String]
    ) throws -> [String: OrderReminderConfiguration]
    func saveOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        orderId: String,
        updatedAt: Date
    ) throws
}

struct ScheduledOrderReminderOccurrence: Equatable {
    let order: Order
    let offsetDays: Int
    let remindAt: Date
}

enum ScheduledOrderReminderQueryError: Error, Equatable {
    case invalidLimit
}

protocol ScheduledOrderReminderRepository {
    func fetchScheduledOrderReminderOccurrences(
        after date: Date,
        limit: Int
    ) throws -> [ScheduledOrderReminderOccurrence]
}

extension ScheduledOrderReminderRepository
where Self: OrderRepository & OrderReminderConfigurationRepository {
    func fetchScheduledOrderReminderOccurrences(
        after date: Date,
        limit: Int
    ) throws -> [ScheduledOrderReminderOccurrence] {
        guard (1...60).contains(limit) else {
            throw ScheduledOrderReminderQueryError.invalidLimit
        }
        let calendar = Calendar(identifier: .gregorian)
        let orders = try fetchOrders()
            .filter(\.hasScheduledReminderState)
            .filter { $0.dueAt > date }
        let configurations = try fetchOrderReminderConfigurations(
            orderIds: orders.map(\.id)
        )
        return
            orders
            .flatMap { order -> [ScheduledOrderReminderOccurrence] in
                let configuration = configurations[order.id] ?? .initialDefault
                guard configuration.isEnabled else {
                    return []
                }
                let offsets =
                    configuration.dayOffsets
                    + (configuration.includesDueTime ? [0] : [])
                return offsets.compactMap { offsetDays in
                    guard
                        let remindAt = calendar.date(
                            byAdding: .day,
                            value: -offsetDays,
                            to: order.dueAt
                        ),
                        remindAt > date
                    else {
                        return nil
                    }
                    return ScheduledOrderReminderOccurrence(
                        order: order,
                        offsetDays: offsetDays,
                        remindAt: remindAt
                    )
                }
            }
            .sorted {
                if $0.remindAt != $1.remindAt {
                    return $0.remindAt < $1.remindAt
                }
                if $0.order.dueAt != $1.order.dueAt {
                    return $0.order.dueAt < $1.order.dueAt
                }
                if $0.order.id != $1.order.id {
                    return $0.order.id < $1.order.id
                }
                return $0.offsetDays > $1.offsetDays
            }
            .prefix(limit)
            .map { $0 }
    }
}

protocol PaymentReminderConfigurationRepository {
    func fetchPaymentReminderConfiguration() throws -> PaymentReminderConfiguration
    func savePaymentReminderConfiguration(
        _ configuration: PaymentReminderConfiguration,
        updatedAt: Date
    ) throws
}

struct PaymentPendingSummary: Equatable {
    static let empty = PaymentPendingSummary(
        orderCount: 0,
        totalBalance: 0
    )

    let orderCount: Int
    let totalBalance: Decimal
}

protocol PaymentPendingSummaryRepository {
    func fetchPaymentPendingSummary(at date: Date) throws -> PaymentPendingSummary
}

struct PaymentReceiptVoid: Equatable {
    let id: String
    let receiptId: String
    let reason: String?
    let voidedAt: Date
    let createdAt: Date
}

struct PaymentReceipt: Equatable {
    let id: String
    let orderId: String
    let amount: Decimal
    let receivedAt: Date
    let note: String?
    let createdAt: Date
    let void: PaymentReceiptVoid?

    var isVoided: Bool {
        void != nil
    }
}

struct NewPaymentReceipt: Equatable {
    let amount: Decimal
    let receivedAt: Date
    let note: String?
    let createdAt: Date
}

enum PaymentReceiptPersistenceError: Error, Equatable {
    case orderNotFound
    case quotedPriceMissing
    case invalidAmount
    case exceedsBalance
    case receiptNotFound
    case alreadyVoided
    case invalidStoredAmount
    case directPaidTotalMutation
}

protocol PaymentReceiptRepository {
    func recordPayment(
        orderId: String,
        amount: Decimal,
        receivedAt: Date,
        note: String?,
        createdAt: Date
    ) throws -> PaymentReceipt
    func recordRemainingBalancePayment(
        orderId: String,
        receivedAt: Date,
        note: String?,
        createdAt: Date
    ) throws -> PaymentReceipt
    func voidPaymentReceipt(
        receiptId: String,
        reason: String?,
        voidedAt: Date,
        createdAt: Date
    ) throws -> PaymentReceiptVoid
    func fetchPaymentReceipts(orderId: String) throws -> [PaymentReceipt]
    func fetchLegacyPaidAmount(orderId: String) throws -> Decimal
}

extension PaymentPendingSummaryRepository where Self: OrderRepository {
    func fetchPaymentPendingSummary(at date: Date) throws -> PaymentPendingSummary {
        let eligibleOrders = try fetchOrders().filter {
            $0.hasPaymentPending(at: date)
        }
        return PaymentPendingSummary(
            orderCount: eligibleOrders.count,
            totalBalance: eligibleOrders.reduce(Decimal.zero) {
                $0 + max($1.balanceDue ?? 0, 0)
            }
        )
    }
}

protocol OrderStatusChangeRepository {
    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]?,
        allowInventoryShortage: Bool,
        transactionIdProvider: () -> String
    ) throws -> Order
}

extension OrderStatusChangeRepository {
    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]?,
        transactionIdProvider: () -> String
    ) throws -> Order {
        try changeOrderStatus(
            order: order,
            status: status,
            updatedAt: updatedAt,
            usageId: usageId,
            extraIngredients: extraIngredients,
            allowInventoryShortage: false,
            transactionIdProvider: transactionIdProvider
        )
    }
}

protocol OrderRecipeUsageRepository {
    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage?
    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws
}

protocol OrderIngredientCostRepository {
    func fetchOrderIngredientCosts(orderId: String) throws -> [OrderIngredientCost]
}

protocol OrderExtraIngredientRepository {
    func save(_ ingredient: OrderExtraIngredient) throws
    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient]
    func deleteOrderExtraIngredient(id: String) throws
    func deleteOrderExtraIngredient(id: String, updatedAt: Date) throws
}

extension OrderExtraIngredientRepository {
    func deleteOrderExtraIngredient(id: String, updatedAt _: Date) throws {
        try deleteOrderExtraIngredient(id: id)
    }
}

protocol OrderInventoryReservationRepository {
    func fetchOrderInventoryReservations(orderId: String) throws -> [OrderInventoryReservation]
    func fetchInventoryReservationTotal(
        inventoryItemId: String,
        excludingOrderId: String?
    ) throws -> Double
    func fetchOrderInventoryReservationEvents(
        orderId: String,
        limit: Int
    ) throws -> [OrderInventoryReservationEvent]
    func fetchOrderInventoryReservationRepair(orderId: String) throws -> OrderInventoryReservationRepair?
    func fetchOrderInventoryReservationPlanningSnapshot(
        orderIds: [String]
    ) throws -> OrderInventoryReservationPlanningSnapshot
}

protocol ProjectedIngredientDemandRepository {
    func fetchProjectedIngredientDemandSummary(
        at date: Date
    ) throws -> ProjectedIngredientDemandSummary
}

extension ProjectedIngredientDemandRepository
where Self: InventoryItemRepository & OrderRepository & OrderInventoryReservationRepository {
    func fetchProjectedIngredientDemandSummary(
        at date: Date
    ) throws -> ProjectedIngredientDemandSummary {
        let inventoryItems = try fetchInventoryItems()
        let activeOrders = try fetchOrders().filter(\.hasActiveReminderState)
        let planningSnapshot = try fetchOrderInventoryReservationPlanningSnapshot(
            orderIds: activeOrders.map(\.id)
        )
        return try ProjectedIngredientDemand.summary(
            inventoryItems: inventoryItems,
            orders: activeOrders,
            at: date,
            planningSnapshot: planningSnapshot
        )
    }
}

protocol OrderInventoryReservationMutationRepository {
    func saveOrder(
        _ order: Order,
        replacingExtraIngredients extraIngredients: [OrderExtraIngredient],
        allowInventoryShortage: Bool
    ) throws
    func repairOrderInventoryReservations(
        limit: Int,
        at timestamp: Date,
        activationId: String
    ) throws -> OrderInventoryReservationRepairSummary
}

protocol OrderReminderPlanOrderMutationRepository {
    func saveOrder(
        _ order: Order,
        replacingExtraIngredients extraIngredients: [OrderExtraIngredient],
        reminderConfiguration: OrderReminderConfiguration,
        allowInventoryShortage: Bool
    ) throws
    func saveOrder(
        _ order: Order,
        replacingExtraIngredients extraIngredients: [OrderExtraIngredient],
        reminderConfiguration: OrderReminderConfiguration,
        openingPayment: NewPaymentReceipt?,
        allowInventoryShortage: Bool
    ) throws
    func saveOrder(
        _ order: Order,
        replacingExtraIngredients extraIngredients: [OrderExtraIngredient],
        replacingChecklistItems checklistItems: [OrderChecklistItem],
        reminderConfiguration: OrderReminderConfiguration,
        openingPayment: NewPaymentReceipt?,
        allowInventoryShortage: Bool
    ) throws
    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]?,
        reminderConfiguration: OrderReminderConfiguration,
        allowInventoryShortage: Bool,
        transactionIdProvider: () -> String
    ) throws -> Order
}

protocol OrderChecklistRepository {
    func save(_ item: OrderChecklistItem) throws
    func fetchOrderChecklistItems(orderId: String) throws -> [OrderChecklistItem]
    func deleteOrderChecklistItem(id: String) throws
}

protocol OrderTemplateRepository {
    func fetchOrderTemplates() throws -> [OrderTemplate]
    func save(_ template: OrderTemplate) throws
    func deleteOrderTemplate(id: String) throws
    func fetchOrderCakeRequirementChoices(field: OrderCakeRequirementField) throws -> [String]
    func saveOrderCakeRequirementChoices(
        _ choices: [(field: OrderCakeRequirementField, value: String)],
        at date: Date
    ) throws
}

extension OrderTemplateRepository {
    func fetchOrderCakeRequirementChoices(field: OrderCakeRequirementField) throws -> [String] {
        []
    }

    func saveOrderCakeRequirementChoices(
        _: [(field: OrderCakeRequirementField, value: String)],
        at _: Date
    ) throws {}
}

protocol OrderPhotoRepository {
    func save(_ photo: OrderPhoto) throws
    func fetchOrderPhoto(id: String) throws -> OrderPhoto?
    func fetchOrderPhotos(orderId: String) throws -> [OrderPhoto]
    func fetchOrderPhotos(kind: OrderPhotoKind) throws -> [OrderPhoto]
    func deleteOrderPhoto(id: String) throws
    func deleteOrderPhoto(id: String, cleanupRelativePath: String?) throws
}

protocol InventoryTransactionRepository {
    func save(_ transaction: InventoryTransaction) throws
    func fetchInventoryTransaction(id: String) throws -> InventoryTransaction?
    func fetchInventoryTransactions(inventoryItemId: String) throws -> [InventoryTransaction]
}

protocol InventoryStockBatchRepository {
    func save(_ batch: InventoryStockBatch) throws
    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws
    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws
    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws
    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch]
}

struct InventoryExpiryReminderCandidate: Equatable {
    let inventoryItemId: String
    let itemName: String
    let unit: InventoryUnit
    let batch: InventoryStockBatch
}

enum InventoryExpiryReminderQueryError: Error, Equatable {
    case invalidLimit
    case invalidDateRange
}

protocol InventoryExpiryReminderRepository {
    func fetchInventoryExpiryReminderCandidates(
        expiringFrom: Date,
        through: Date,
        limit: Int
    ) throws -> [InventoryExpiryReminderCandidate]
}

extension InventoryExpiryReminderRepository
where Self: InventoryItemRepository & InventoryStockBatchRepository {
    func fetchInventoryExpiryReminderCandidates(
        expiringFrom: Date,
        through: Date,
        limit: Int
    ) throws -> [InventoryExpiryReminderCandidate] {
        guard (1...60).contains(limit) else {
            throw InventoryExpiryReminderQueryError.invalidLimit
        }
        guard expiringFrom <= through else {
            throw InventoryExpiryReminderQueryError.invalidDateRange
        }
        return try fetchInventoryItems()
            .filter { $0.type == .standard }
            .flatMap { item in
                try fetchInventoryStockBatches(inventoryItemId: item.id)
                    .compactMap { batch in
                        guard batch.remainingQuantity > 0,
                            let expiresAt = batch.expiresAt,
                            expiresAt >= expiringFrom,
                            expiresAt <= through
                        else {
                            return nil
                        }
                        return InventoryExpiryReminderCandidate(
                            inventoryItemId: item.id,
                            itemName: item.name,
                            unit: item.unit,
                            batch: batch
                        )
                    }
            }
            .sorted {
                let lhsExpiry = $0.batch.expiresAt ?? .distantFuture
                let rhsExpiry = $1.batch.expiresAt ?? .distantFuture
                if lhsExpiry != rhsExpiry {
                    return lhsExpiry < rhsExpiry
                }
                let nameOrder = $0.itemName.localizedCaseInsensitiveCompare(
                    $1.itemName
                )
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return $0.batch.id < $1.batch.id
            }
            .prefix(limit)
            .map { $0 }
    }
}

protocol VoiceInventoryImportRepository {
    func saveVoiceInventoryImport(
        items: [InventoryItem],
        batches: [InventoryStockBatch]
    ) throws
}

protocol ExpiredStockDisposalRepository {
    func saveExpiredStockDisposal(
        item: InventoryItem,
        batches: [InventoryStockBatch],
        transaction: InventoryTransaction
    ) throws
}

protocol PricingRuleRepository {
    func save(_ rule: PricingRule) throws
    func fetchPricingRule(id: String) throws -> PricingRule?
}
