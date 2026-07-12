import XCTest
@testable import CloudBakeOwner

func makeOrder(
    id: String,
    title: String = "Vanilla Birthday",
    customerId: String? = nil,
    recipeId: String? = nil,
    cakeDesignId: String? = nil,
    customerReferencePhotoId: String? = nil,
    status: OrderStatus = .draft,
    dueAt: Date,
    createdAt: Date = Date(timeIntervalSince1970: 1_800_060_000),
    quotedPrice: Decimal? = nil,
    depositPaid: Decimal? = nil
) -> Order {
    return Order(
        id: id,
        customerId: customerId,
        cakeDesignId: cakeDesignId,
        customerReferencePhotoId: customerReferencePhotoId,
        recipeId: recipeId,
        title: title,
        customerName: "Amy",
        status: status,
        dueAt: dueAt,
        fulfillmentType: .pickup,
        deliveryAddress: nil,
        cakeNotes: nil,
        quotedPrice: quotedPrice,
        depositPaid: depositPaid,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}

func date(byAddingDays days: Int, to date: Date, calendar: Calendar) -> Date {
    guard let date = calendar.date(byAdding: .day, value: days, to: date) else {
        XCTFail("Expected test date fixture to be valid.")
        return .distantPast
    }

    return date
}

func decimal(_ text: String) -> Decimal {
    guard let amount = Decimal(string: text) else {
        XCTFail("Expected decimal test fixture to be valid.")
        return 0
    }

    return amount
}

func makeCustomer(
    id: String,
    name: String,
    phone: String = "5550101",
    address: String? = nil,
    email: String? = nil,
    likes: String? = nil,
    dislikes: String? = nil,
    allergies: String? = nil,
    dietaryRestrictions: String? = nil,
    notes: String? = nil
) -> Customer {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return Customer(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        likes: likes,
        dislikes: dislikes,
        allergies: allergies,
        dietaryRestrictions: dietaryRestrictions,
        notes: notes,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeRecipe(id: String, name: String, notes: String? = nil) -> Recipe {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return Recipe(
        id: id,
        name: name,
        notes: notes,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeCakeDesign(
    id: String,
    name: String,
    notes: String? = nil,
    photoReference: String? = nil,
    sourceKind: CakeDesignSourceKind = .ownerMade,
    tags: [String] = []
) -> CakeDesign {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return CakeDesign(
        id: id,
        name: name,
        notes: notes,
        photoReference: photoReference,
        sourceKind: sourceKind,
        tags: tags,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeInventoryItem(
    id: String,
    name: String,
    unit: InventoryUnit = .gram,
    currentQuantity: Double = 500,
    minimumQuantity: Double = 100
) -> InventoryItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return InventoryItem(
        id: id,
        name: name,
        unit: unit,
        currentQuantity: currentQuantity,
        minimumQuantity: minimumQuantity,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeChecklistItem(
    id: String,
    orderId: String,
    title: String,
    isCompleted: Bool = false,
    sortOrder: Int = 0
) -> OrderChecklistItem {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return OrderChecklistItem(
        id: id,
        orderId: orderId,
        title: title,
        isCompleted: isCompleted,
        sortOrder: sortOrder,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeOrderPhoto(
    id: String,
    orderId: String,
    kind: OrderPhotoKind,
    caption: String? = nil,
    tags: [String] = []
) -> OrderPhoto {
    let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
    return OrderPhoto(
        id: id,
        orderId: orderId,
        kind: kind,
        localPhotoPath: "OrderPhotos/\(orderId)/\(id).jpg",
        caption: caption,
        tags: tags,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

func makeIncrementingIdGenerator(prefix: String) -> () -> String {
    var counter = 0
    return {
        counter += 1
        return "\(prefix)-\(counter)"
    }
}

final class FakeOrderRepository: OrderRepository,
    CustomerRepository,
    CustomerImportantDateRepository,
    RecipeRepository,
    RecipeComponentRepository,
    RecipeIngredientRepository,
    CakeDesignRepository,
    InventoryItemRepository,
    InventoryStockBatchRepository,
    OrderRecipeUsageRepository,
    OrderIngredientCostRepository,
    OrderStatusChangeRepository,
    OrderExtraIngredientRepository,
    OrderChecklistRepository,
    OrderPhotoRepository {
    var orders: [Order] = []
    var customers: [Customer] = []
    var customerImportantDates: [CustomerImportantDate] = []
    var recipes: [Recipe] = []
    var recipeComponents: [RecipeComponent] = []
    var recipeIngredients: [RecipeIngredient] = []
    var cakeDesigns: [CakeDesign] = []
    var inventoryItems: [InventoryItem] = []
    var inventoryStockBatches: [InventoryStockBatch] = []
    var usages: [OrderRecipeUsage] = []
    var ingredientCosts: [OrderIngredientCost] = []
    var extraIngredients: [OrderExtraIngredient] = []
    var checklistItems: [OrderChecklistItem] = []
    var orderPhotos: [OrderPhoto] = []
    var recordedTransactionIds: [String] = []
    var recordRecipeUsageError: Error?
    var changeOrderStatusError: Error?
    var savePromotedDesignError: Error?
    var pendingDesignPhotoCleanupPaths: [String] = []

    func save(_ order: Order) throws {
        orders.removeAll { $0.id == order.id }
        orders.append(order)
    }

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders.sorted { lhs, rhs in
            lhs.dueAt == rhs.dueAt ? lhs.title < rhs.title : lhs.dueAt < rhs.dueAt
        }
    }

    func save(_ customer: Customer) throws {
        customers.removeAll { $0.id == customer.id }
        customers.append(customer)
    }

    func fetchCustomer(id: String) throws -> Customer? {
        customers.first { $0.id == id }
    }

    func fetchCustomers() throws -> [Customer] {
        customers
    }

    func deleteCustomer(id: String) throws {
        customers.removeAll { $0.id == id }
        customerImportantDates.removeAll { $0.customerId == id }
        orders = orders.map { order in
            guard order.customerId == id else {
                return order
            }

            return Order(
                id: order.id,
                customerId: nil,
                cakeDesignId: order.cakeDesignId,
                recipeId: order.recipeId,
                recipeScaleMultiplier: order.recipeScaleMultiplier,
                title: order.title,
                customerName: order.customerName,
                status: order.status,
                dueAt: order.dueAt,
                fulfillmentType: order.fulfillmentType,
                deliveryAddress: order.deliveryAddress,
                cakeNotes: order.cakeNotes,
                cakeMessage: order.cakeMessage,
                quotedPrice: order.quotedPrice,
                depositPaid: order.depositPaid,
                paymentNotes: order.paymentNotes,
                createdAt: order.createdAt,
                updatedAt: order.updatedAt
            )
        }
    }

    func save(_ importantDate: CustomerImportantDate) throws {
        customerImportantDates.removeAll { $0.id == importantDate.id }
        customerImportantDates.append(importantDate)
    }

    func fetchCustomerImportantDates(customerId: String) throws -> [CustomerImportantDate] {
        customerImportantDates.filter { $0.customerId == customerId }
    }

    func save(_ recipe: Recipe) throws {
        recipes.removeAll { $0.id == recipe.id }
        recipes.append(recipe)
    }

    func fetchRecipe(id: String) throws -> Recipe? {
        recipes.first { $0.id == id }
    }

    func fetchRecipes() throws -> [Recipe] {
        recipes.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func save(_ component: RecipeComponent) throws {
        recipeComponents.removeAll { $0.id == component.id }
        recipeComponents.append(component)
    }

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        recipeComponents.first { $0.id == id }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        recipeComponents.filter { $0.recipeId == recipeId }
    }

    func save(_ ingredient: RecipeIngredient) throws {
        recipeIngredients.removeAll { $0.id == ingredient.id }
        recipeIngredients.append(ingredient)
    }

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        recipeIngredients.first { $0.id == id }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        recipeIngredients.filter { $0.componentId == componentId }
    }

    func deleteRecipeIngredient(id: String) throws {
        recipeIngredients.removeAll { $0.id == id }
    }

    func save(_ design: CakeDesign) throws {
        cakeDesigns.removeAll { $0.id == design.id }
        cakeDesigns.append(design)
    }

    func deleteCakeDesign(id: String) throws {
        cakeDesigns.removeAll { $0.id == id }
    }

    func savePromotedDesign(
        _ design: CakeDesign,
        linking order: Order,
        photo: OrderPhoto,
        cleanupRelativePath: String?
    ) throws {
        if let savePromotedDesignError { throw savePromotedDesignError }
        try save(design)
        try save(order)
        try save(photo)
        if let cleanupRelativePath {
            pendingDesignPhotoCleanupPaths.append(cleanupRelativePath)
        }
    }

    func fetchPendingDesignPhotoCleanupPaths() throws -> [String] {
        pendingDesignPhotoCleanupPaths
    }

    func deletePendingDesignPhotoCleanupPath(_ relativePath: String) throws {
        pendingDesignPhotoCleanupPaths.removeAll { $0 == relativePath }
    }

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        cakeDesigns.first { $0.id == id }
    }

    func fetchCakeDesign(originatingOrderPhotoId: String) throws -> CakeDesign? {
        cakeDesigns.first { $0.originatingOrderPhotoId == originatingOrderPhotoId }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        cakeDesigns.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func save(_ item: InventoryItem) throws {
        inventoryItems.removeAll { $0.id == item.id }
        inventoryItems.append(item)
    }

    func fetchInventoryItem(id: String) throws -> InventoryItem? {
        inventoryItems.first { $0.id == id }
    }

    func fetchInventoryItems() throws -> [InventoryItem] {
        inventoryItems.filter { !$0.isArchived }.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func fetchArchivedInventoryItems() throws -> [InventoryItem] {
        inventoryItems.filter(\.isArchived)
    }

    func save(_ batch: InventoryStockBatch) throws {
        inventoryStockBatches.removeAll { $0.id == batch.id }
        inventoryStockBatches.append(batch)
    }

    func saveBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try save(item)
        try save(batch)
    }

    func deleteBatchCorrection(item: InventoryItem, batch: InventoryStockBatch) throws {
        try save(item)
        inventoryStockBatches.removeAll { $0.id == batch.id }
    }

    func replaceInventoryStock(item: InventoryItem, batches: [InventoryStockBatch]) throws {
        try save(item)
        inventoryStockBatches.removeAll { $0.inventoryItemId == item.id }
        inventoryStockBatches.append(contentsOf: batches)
    }

    func fetchInventoryStockBatches(inventoryItemId: String) throws -> [InventoryStockBatch] {
        inventoryStockBatches.filter { $0.inventoryItemId == inventoryItemId }
    }

    func fetchOrderRecipeUsage(orderId: String) throws -> OrderRecipeUsage? {
        usages.first { $0.orderId == orderId }
    }

    func fetchOrderIngredientCosts(orderId: String) throws -> [OrderIngredientCost] {
        ingredientCosts.filter { $0.orderId == orderId }
    }

    func save(_ ingredient: OrderExtraIngredient) throws {
        extraIngredients.removeAll { $0.id == ingredient.id }
        extraIngredients.append(ingredient)
    }

    func fetchOrderExtraIngredients(orderId: String) throws -> [OrderExtraIngredient] {
        extraIngredients
            .filter { $0.orderId == orderId }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id < $1.id
                }

                return $0.createdAt < $1.createdAt
            }
    }

    func deleteOrderExtraIngredient(id: String) throws {
        extraIngredients.removeAll { $0.id == id }
    }

    func save(_ item: OrderChecklistItem) throws {
        checklistItems.removeAll { $0.id == item.id }
        checklistItems.append(item)
    }

    func fetchOrderChecklistItems(orderId: String) throws -> [OrderChecklistItem] {
        checklistItems
            .filter { $0.orderId == orderId }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.id < $1.id
                }

                return $0.sortOrder < $1.sortOrder
            }
    }

    func deleteOrderChecklistItem(id: String) throws {
        checklistItems.removeAll { $0.id == id }
    }

    func save(_ photo: OrderPhoto) throws {
        orderPhotos.removeAll { $0.id == photo.id }
        orderPhotos.append(photo)
    }

    func fetchOrderPhotos(orderId: String) throws -> [OrderPhoto] {
        orderPhotos
            .filter { $0.orderId == orderId }
            .sorted {
                if $0.kind == $1.kind {
                    if $0.createdAt == $1.createdAt {
                        return $0.id < $1.id
                    }

                    return $0.createdAt < $1.createdAt
                }

                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    func fetchOrderPhoto(id: String) throws -> OrderPhoto? {
        orderPhotos.first { $0.id == id }
    }

    func fetchOrderPhotos(kind: OrderPhotoKind) throws -> [OrderPhoto] {
        orderPhotos.filter { $0.kind == kind }
    }

    func deleteOrderPhoto(id: String) throws {
        orderPhotos.removeAll { $0.id == id }
    }

    func deleteOrderPhoto(id: String, cleanupRelativePath: String?) throws {
        orderPhotos.removeAll { $0.id == id }
        if let cleanupRelativePath {
            pendingDesignPhotoCleanupPaths.append(cleanupRelativePath)
        }
    }

    func recordRecipeUsage(
        for order: Order,
        usageId: String,
        usedAt: Date,
        transactionIdProvider: () -> String
    ) throws {
        if let recordRecipeUsageError {
            throw recordRecipeUsageError
        }
        guard let recipeId = order.recipeId else {
            throw OrderRecipeUsageError.orderHasNoLinkedRecipe
        }

        recordedTransactionIds.append(transactionIdProvider())
        usages.append(
            OrderRecipeUsage(
                id: usageId,
                orderId: order.id,
                recipeId: recipeId,
                recipeScaleMultiplier: order.recipeScaleMultiplier,
                usedAt: usedAt,
                createdAt: usedAt,
                updatedAt: usedAt
            )
        )
    }

    func changeOrderStatus(
        order: Order,
        status: OrderStatus,
        updatedAt: Date,
        usageId: String,
        extraIngredients: [OrderExtraIngredient]?,
        transactionIdProvider: () -> String
    ) throws -> Order {
        if let changeOrderStatusError {
            throw changeOrderStatusError
        }

        if let extraIngredients {
            self.extraIngredients.removeAll { $0.orderId == order.id }
            self.extraIngredients.append(contentsOf: extraIngredients)
        }

        let updatedOrder = Order(
            id: order.id,
            customerId: order.customerId,
            cakeDesignId: order.cakeDesignId,
            recipeId: order.recipeId,
            recipeScaleMultiplier: order.recipeScaleMultiplier,
            title: order.title,
            customerName: order.customerName,
            status: status,
            dueAt: order.dueAt,
            fulfillmentType: order.fulfillmentType,
            deliveryAddress: order.deliveryAddress,
            cakeNotes: order.cakeNotes,
            cakeMessage: order.cakeMessage,
            quotedPrice: order.quotedPrice,
            depositPaid: order.depositPaid,
            paymentNotes: order.paymentNotes,
            createdAt: order.createdAt,
            updatedAt: updatedAt
        )
        try save(updatedOrder)

        if shouldRecordRecipeUsage(from: order.status, to: status),
           let recipeId = order.recipeId,
           usages.first(where: { $0.orderId == order.id }) == nil {
            recordedTransactionIds.append(transactionIdProvider())
            usages.append(
                OrderRecipeUsage(
                    id: usageId,
                    orderId: order.id,
                    recipeId: recipeId,
                    recipeScaleMultiplier: order.recipeScaleMultiplier,
                    usedAt: updatedAt,
                    createdAt: updatedAt,
                    updatedAt: updatedAt
                )
            )
        }

        return updatedOrder
    }

    private func shouldRecordRecipeUsage(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        currentStatus == .confirmed && (newStatus == .ready || newStatus == .completed)
    }
}

final class FakeOrderPhotoFileStore: OrderPhotoFileStore {
    struct SavedPhoto: Equatable {
        let data: Data
        let orderId: String
        let photoId: String
    }

    var savedPhotos: [SavedPhoto] = []
    var deletedRelativePaths: [String] = []
    var deleteError: Error?

    func saveOrderPhoto(data: Data, orderId: String, photoId: String) throws -> String {
        savedPhotos.append(SavedPhoto(data: data, orderId: orderId, photoId: photoId))
        return "OrderPhotos/\(orderId)/\(photoId).jpg"
    }

    func deleteOrderPhoto(relativePath: String) throws {
        if let deleteError { throw deleteError }
        deletedRelativePaths.append(relativePath)
    }

    func fileURL(for relativePath: String) -> URL {
        URL(fileURLWithPath: "/tmp").appendingPathComponent(relativePath)
    }
}

final class FakeDesignPhotoLibrary: DesignPhotoLibrary {
    var savedFileURLs: [URL] = []
    var savedData: [Data] = []
    var savedReference = "photos://asset-design"
    var saveError: Error?
    var shouldSuspendSave = false
    private(set) var isSaveSuspended = false
    private var saveContinuation: CheckedContinuation<String, Error>?

    func savePhoto(at fileURL: URL) async throws -> String {
        savedFileURLs.append(fileURL)
        if let saveError { throw saveError }
        if shouldSuspendSave {
            return try await withCheckedThrowingContinuation { continuation in
                saveContinuation = continuation
                isSaveSuspended = true
            }
        }
        return savedReference
    }

    func savePhoto(data: Data) async throws -> String {
        savedData.append(data)
        if let saveError { throw saveError }
        return savedReference
    }

    func completeSuspendedSave() {
        saveContinuation?.resume(returning: savedReference)
        saveContinuation = nil
        isSaveSuspended = false
    }

    func containsAsset(identifier: String) -> Bool {
        savedReference == PhotoKitDesignPhotoLibrary.referencePrefix + identifier
    }
}
