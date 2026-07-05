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

protocol CakeDesignRepository {
    func save(_ design: CakeDesign) throws
    func fetchCakeDesign(id: String) throws -> CakeDesign?
}

protocol CustomerRepository {
    func save(_ customer: Customer) throws
    func fetchCustomer(id: String) throws -> Customer?
}

protocol OrderRepository {
    func save(_ order: Order) throws
    func fetchOrder(id: String) throws -> Order?
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
    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch]
}

protocol PricingRuleRepository {
    func save(_ rule: PricingRule) throws
    func fetchPricingRule(id: String) throws -> PricingRule?
}
