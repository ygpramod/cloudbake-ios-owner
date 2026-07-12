import XCTest
@testable import CloudBakeOwner

final class InventoryCSVServiceTests: XCTestCase {
    func testRecipeExportIncludesIgnoredExampleAndPipeSeparatedIngredients() throws {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let flour = InventoryItem(
            id: "flour",
            name: "Cake Flour",
            aliases: ["Maida"],
            unit: .gram,
            currentQuantity: 500,
            minimumQuantity: 100,
            createdAt: now,
            updatedAt: now
        )
        repository.inventoryItems = [flour]
        repository.recipes = [Recipe(id: "recipe", name: "Vanilla Sponge", notes: "Bake, then cool", createdAt: now, updatedAt: now)]
        repository.components = [RecipeComponent(id: "component", recipeId: "recipe", name: "Ingredients", sortOrder: 0, createdAt: now, updatedAt: now)]
        repository.ingredients = [RecipeIngredient(id: "ingredient", componentId: "component", inventoryItemId: flour.id, quantity: 250, unit: .gram, note: nil, createdAt: now, updatedAt: now)]

        let csv = try RecipeCSVService().exportCSV(repository: repository)

        XCTAssertTrue(csv.contains("name,recipe,ingredients"))
        XCTAssertTrue(csv.contains("# Example - ignored during import"))
        XCTAssertTrue(csv.contains("Vanilla Sponge,\"Bake, then cool\",Cake Flour:250:g"))
    }

    func testRecipeImportSkipsExampleAndMatchesInventoryAlias() throws {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        repository.inventoryItems = [
            InventoryItem(
                id: "flour",
                name: "Cake Flour",
                aliases: ["Maida"],
                unit: .gram,
                currentQuantity: 500,
                minimumQuantity: 100,
                createdAt: now,
                updatedAt: now
            )
        ]
        let service = RecipeCSVService(
            idGenerator: makeIncrementingIdGenerator(prefix: "recipe-csv"),
            dateProvider: { now }
        )

        let summary = try service.importCSV(
            """
            name,recipe,ingredients
            # Example - ignored during import,,Cake Flour:250:g | Sugar:200:g
            Vanilla Sponge,"Bake, then cool",Maida:250:g
            """,
            repository: repository
        )

        XCTAssertEqual(summary, RecipeCSVImportSummary(importedRecipeCount: 1, importedIngredientCount: 1))
        XCTAssertEqual(repository.recipes.map(\.name), ["Vanilla Sponge"])
        XCTAssertEqual(repository.recipes.first?.notes, "Bake, then cool")
        XCTAssertEqual(repository.ingredients.first?.inventoryItemId, "flour")
        XCTAssertEqual(repository.ingredients.first?.quantity, 250)
    }

    func testRecipeImportRejectsUnmatchedIngredientBeforeSaving() throws {
        let repository = FakeRecipeRepository()

        XCTAssertThrowsError(
            try RecipeCSVService().importCSV(
                """
                name,recipe,ingredients
                Vanilla Sponge,,Unknown Flour:250:g
                """,
                repository: repository
            )
        ) { error in
            XCTAssertEqual(
                error as? RecipeCSVError,
                .invalidRow(2, "Ingredient 'Unknown Flour' does not match active inventory.")
            )
        }
        XCTAssertTrue(repository.recipes.isEmpty)
    }

    func testRecipeImportRejectsDuplicateHeadersAndIncompatibleUnits() throws {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        repository.inventoryItems = [
            InventoryItem(id: "flour", name: "Cake Flour", unit: .gram, currentQuantity: 1, minimumQuantity: 0, createdAt: now, updatedAt: now)
        ]

        XCTAssertThrowsError(
            try RecipeCSVService().importCSV(
                "name,Name,recipe,ingredients\nCake,,,Cake Flour:250:g\n",
                repository: repository
            )
        ) { error in
            XCTAssertEqual(error as? RecipeCSVError, .invalidRow(1, "CSV headers must be unique."))
        }

        XCTAssertThrowsError(
            try RecipeCSVService().importCSV(
                "name,recipe,ingredients\nCake,,Cake Flour:250:ml\n",
                repository: repository
            )
        ) { error in
            XCTAssertEqual(
                error as? RecipeCSVError,
                .invalidRow(2, "Ingredient unit is incompatible with 'Cake Flour'.")
            )
        }
        XCTAssertTrue(repository.recipes.isEmpty)
    }

    func testRecipeImportRepositoryFailureDoesNotPartiallySave() throws {
        enum TestError: Error { case failed }
        let repository = FakeRecipeRepository()
        repository.recipeCSVImportError = TestError.failed

        XCTAssertThrowsError(
            try RecipeCSVService().importCSV(
                "name,recipe,ingredients\nCake,Notes,\n",
                repository: repository
            )
        )
        XCTAssertTrue(repository.recipes.isEmpty)
        XCTAssertTrue(repository.components.isEmpty)
        XCTAssertTrue(repository.ingredients.isEmpty)
    }

    func testRecipeExportIncludesArchivedInventoryAndRejectsMissingReference() throws {
        let repository = FakeRecipeRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let archived = InventoryItem(
            id: "archived-flour",
            name: "Archived Flour",
            unit: .gram,
            currentQuantity: 0,
            minimumQuantity: 0,
            createdAt: now,
            updatedAt: now,
            archivedAt: now
        )
        repository.archivedInventoryItems = [archived]
        repository.recipes = [Recipe(id: "recipe", name: "Cake", notes: nil, createdAt: now, updatedAt: now)]
        repository.components = [RecipeComponent(id: "component", recipeId: "recipe", name: "Ingredients", sortOrder: 0, createdAt: now, updatedAt: now)]
        repository.ingredients = [RecipeIngredient(id: "ingredient", componentId: "component", inventoryItemId: archived.id, quantity: 10, unit: .gram, note: nil, createdAt: now, updatedAt: now)]

        XCTAssertTrue(try RecipeCSVService().exportCSV(repository: repository).contains("Archived Flour:10:g"))

        repository.archivedInventoryItems = []
        XCTAssertThrowsError(try RecipeCSVService().exportCSV(repository: repository)) { error in
            XCTAssertEqual(error as? RecipeCSVError, .missingInventoryReference(archived.id))
        }
    }

    func testExportWritesActiveInventoryWithBatchExpiry() throws {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let expiry = try XCTUnwrap(Self.dateFormatter.date(from: "2026-08-15"))
        let item = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            aliases: ["Maida", "Plain Flour"],
            type: .perishable,
            unit: .gram,
            currentQuantity: 250,
            minimumQuantity: 500,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [item]
        repository.batches = [
            InventoryStockBatch(
                id: "batch-flour",
                inventoryItemId: item.id,
                remainingQuantity: 250,
                expiresAt: expiry,
                amount: Decimal(string: "2.50"),
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let service = InventoryCSVService()

        let csv = try service.exportCSV(repository: repository)

        XCTAssertTrue(csv.contains("name,aliases,type,unit,current_quantity,minimum_quantity,batch_quantity,amount,expiry_date"))
        XCTAssertTrue(csv.contains("Cake flour,\"Maida, Plain Flour\",Perishable,g,250,500,250,2.5,2026-08-15"))
    }

    func testImportCreatesInventoryAndBatchesFromCSV() throws {
        let repository = FakeInventoryItemRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = InventoryCSVService(
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { now }
        )

        let summary = try service.importCSV(
            """
            name,aliases,type,unit,current_quantity,minimum_quantity,batch_quantity,amount,expiry_date
            Cake flour,"Maida, Plain Flour",Perishable,g,250,500,250,2.50,2026-08-15
            Butter,,Standard,kg,2,1,2,,
            """,
            repository: repository
        )

        XCTAssertEqual(summary, InventoryCSVImportSummary(importedItemCount: 2, importedBatchCount: 2))
        XCTAssertEqual(repository.items.map(\.name).sorted(), ["Butter", "Cake flour"])
        XCTAssertEqual(repository.items.first { $0.name == "Cake flour" }?.currentQuantity, 250)
        XCTAssertEqual(repository.items.first { $0.name == "Cake flour" }?.aliases, ["Maida", "Plain Flour"])
        XCTAssertEqual(repository.items.first { $0.name == "Cake flour" }?.type, .perishable)
        XCTAssertEqual(repository.items.first { $0.name == "Butter" }?.unit, .kilogram)
        XCTAssertEqual(repository.batches.count, 2)
        XCTAssertEqual(repository.batches.first { $0.remainingQuantity == 250 }?.amount, Decimal(string: "2.50"))
    }

    func testImportUpdatesExistingInventoryByNameAndUnit() throws {
        let repository = FakeInventoryItemRepository()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = InventoryItem(
            id: "inventory-flour",
            name: "Cake flour",
            aliases: ["Maida", "Plain Flour"],
            type: .standard,
            unit: .gram,
            currentQuantity: 100,
            minimumQuantity: 50,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.items = [existing]
        repository.batches = [
            InventoryStockBatch(
                id: "old-batch",
                inventoryItemId: existing.id,
                remainingQuantity: 100,
                expiresAt: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
        let service = InventoryCSVService(
            idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
            dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let summary = try service.importCSV(
            """
            name,aliases,type,unit,current_quantity,minimum_quantity,batch_quantity,expiry_date
            cake flour,"Cake Wheat, Maida",Perishable,g,300,500,125,2026-08-15
            Cake Flour,"Cake Wheat, Maida",Perishable,g,300,500,175,2026-09-30
            """,
            repository: repository
        )

        XCTAssertEqual(summary, InventoryCSVImportSummary(importedItemCount: 1, importedBatchCount: 2))
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items[0].id, existing.id)
        XCTAssertEqual(repository.items[0].aliases, ["Cake Wheat", "Maida"])
        XCTAssertEqual(repository.items[0].type, .perishable)
        XCTAssertEqual(repository.items[0].currentQuantity, 300)
        XCTAssertEqual(repository.items[0].minimumQuantity, 500)
        XCTAssertEqual(repository.batches.map(\.remainingQuantity).sorted(), [125, 175])
    }

    func testImportRequiresAliasesAndTypeHeaders() throws {
        let service = InventoryCSVService()

        XCTAssertThrowsError(
            try service.importCSV(
                """
                name,type,unit,minimum_quantity,batch_quantity
                Cake flour,Standard,g,500,250
                """,
                repository: FakeInventoryItemRepository()
            )
        ) { error in
            XCTAssertEqual(error as? InventoryCSVError, .missingRequiredHeader("aliases"))
        }

        XCTAssertThrowsError(
            try service.importCSV(
                """
                name,aliases,unit,minimum_quantity,batch_quantity
                Cake flour,Maida,g,500,250
                """,
                repository: FakeInventoryItemRepository()
            )
        ) { error in
            XCTAssertEqual(error as? InventoryCSVError, .missingRequiredHeader("type"))
        }
    }

    func testImportRejectsUnsupportedInventoryType() throws {
        let service = InventoryCSVService()

        XCTAssertThrowsError(
            try service.importCSV(
                """
                name,aliases,type,unit,minimum_quantity,batch_quantity
                Cake flour,Maida,Frozen,g,500,250
                """,
                repository: FakeInventoryItemRepository()
            )
        ) { error in
            XCTAssertEqual(
                error as? InventoryCSVError,
                .invalidRow(2, "Type must be Standard or Perishable.")
            )
        }
    }

    func testImportRejectsConflictingMetadataAcrossBatchRows() throws {
        let service = InventoryCSVService()

        XCTAssertThrowsError(
            try service.importCSV(
                """
                name,aliases,type,unit,minimum_quantity,batch_quantity
                Cake flour,Maida,Standard,g,500,125
                Cake Flour,Plain Flour,Standard,g,500,175
                """,
                repository: FakeInventoryItemRepository()
            )
        ) { error in
            XCTAssertEqual(
                error as? InventoryCSVError,
                .invalidRow(3, "Aliases must match across batch rows for the same item.")
            )
        }

        XCTAssertThrowsError(
            try service.importCSV(
                """
                name,aliases,type,unit,minimum_quantity,batch_quantity
                Cake flour,Maida,Standard,g,500,125
                Cake Flour,maida,Perishable,g,500,175
                """,
                repository: FakeInventoryItemRepository()
            )
        ) { error in
            XCTAssertEqual(
                error as? InventoryCSVError,
                .invalidRow(3, "Type must match across batch rows for the same item.")
            )
        }
    }

    @MainActor
    func testSettingsViewModelReportsExportReadyState() throws {
        let repository = FakeInventoryItemRepository()
        repository.items = [
            InventoryItem(
                id: "inventory-flour",
                name: "Cake flour",
                unit: .gram,
                currentQuantity: 250,
                minimumQuantity: 500,
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        ]
        let viewModel = SettingsViewModel(repository: repository)

        let document = try XCTUnwrap(viewModel.exportInventoryDocument())

        XCTAssertTrue(document.text.contains("Cake flour"))
        XCTAssertEqual(viewModel.statusMessage, "Inventory export is ready. Choose a location to save the CSV.")
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testSettingsViewModelReportsImportedItemsAndBatches() throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        try """
        name,aliases,type,unit,current_quantity,minimum_quantity,batch_quantity,amount,expiry_date
        Cake flour,Maida,Standard,g,250,500,250,2.50,2026-08-15
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        let viewModel = SettingsViewModel(
            repository: FakeInventoryItemRepository(),
            csvService: InventoryCSVService(
                idGenerator: makeIncrementingIdGenerator(prefix: "generated"),
                dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) }
            )
        )

        viewModel.importInventoryCSV(from: temporaryURL)

        XCTAssertEqual(viewModel.statusMessage, "Imported 1 inventory items and 1 stock batches.")
        XCTAssertNil(viewModel.errorMessage)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
