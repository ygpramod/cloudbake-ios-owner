import Foundation

protocol InventoryItemRepository {
    func save(_ item: InventoryItem) throws
    func fetchInventoryItem(id: String) throws -> InventoryItem?
    func fetchInventoryItems() throws -> [InventoryItem]
    func fetchArchivedInventoryItems() throws -> [InventoryItem]
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
}

protocol OrderStatusChangeRepository {
    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]?,
        transactionIdProvider: () -> String
    ) throws -> Order
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

protocol OrderExtraIngredientRepository {
    func save(_ ingredient: OrderExtraIngredient) throws
    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient]
    func deleteOrderExtraIngredient(id: String) throws
}

protocol OrderChecklistRepository {
    func save(_ item: OrderChecklistItem) throws
    func fetchOrderChecklistItems(orderId: String) throws -> [OrderChecklistItem]
    func deleteOrderChecklistItem(id: String) throws
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
