import Foundation
import GRDB

extension GRDBCoreDataRepository {
    func save(_ recipe: Recipe) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO recipes
                    (id, name, notes, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        notes = excluded.notes,
                        created_at_unix_time = excluded.created_at_unix_time,
                        updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    recipe.id,
                    recipe.name,
                    recipe.notes,
                    recipe.createdAt.timeIntervalSince1970,
                    recipe.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipe(id: String) throws -> Recipe? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipes WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return recipe(from: row)
        }
    }

    func fetchRecipes() throws -> [Recipe] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM recipes ORDER BY lower(name), name"
            ).map(recipe)
        }
    }

    func save(_ component: RecipeComponent) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO recipe_components
                    (id, recipe_id, name, sort_order, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        recipe_id = excluded.recipe_id,
                        name = excluded.name,
                        sort_order = excluded.sort_order,
                        created_at_unix_time = excluded.created_at_unix_time,
                        updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    component.id,
                    component.recipeId,
                    component.name,
                    component.sortOrder,
                    component.createdAt.timeIntervalSince1970,
                    component.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipeComponent(id: String) throws -> RecipeComponent? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipe_components WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return recipeComponent(from: row)
        }
    }

    func fetchRecipeComponents(recipeId: String) throws -> [RecipeComponent] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM recipe_components
                    WHERE recipe_id = ?
                    ORDER BY sort_order ASC, lower(name), name
                    """,
                arguments: [recipeId]
            ).map(recipeComponent)
        }
    }

    func fetchRecipeIngredients(componentId: String) throws -> [RecipeIngredient] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM recipe_ingredients
                    WHERE component_id = ?
                    ORDER BY created_at_unix_time ASC, id
                    """,
                arguments: [componentId]
            ).compactMap { row in
                guard let unit = InventoryUnit(rawValue: row["unit"]) else {
                    return nil
                }

                return recipeIngredient(from: row, unit: unit)
            }
        }
    }

    func deleteRecipeIngredient(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM recipe_ingredients WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func save(_ ingredient: RecipeIngredient) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO recipe_ingredients
                    (id, component_id, inventory_item_id, quantity, unit, note, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        component_id = excluded.component_id,
                        inventory_item_id = excluded.inventory_item_id,
                        quantity = excluded.quantity,
                        unit = excluded.unit,
                        note = excluded.note,
                        created_at_unix_time = excluded.created_at_unix_time,
                        updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    ingredient.id,
                    ingredient.componentId,
                    ingredient.inventoryItemId,
                    ingredient.quantity,
                    ingredient.unit.rawValue,
                    ingredient.note,
                    ingredient.createdAt.timeIntervalSince1970,
                    ingredient.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchRecipeIngredient(id: String) throws -> RecipeIngredient? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM recipe_ingredients WHERE id = ?", arguments: [id]),
                  let unit = InventoryUnit(rawValue: row["unit"]) else {
                return nil
            }

            return recipeIngredient(from: row, unit: unit)
        }
    }

    func save(_ design: CakeDesign) throws {
        try writer.write { db in
            try save(design, in: db)
        }
    }

    func deleteCakeDesign(id: String) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM cake_designs WHERE id = ?", arguments: [id])
        }
    }

    func save(_ design: CakeDesign, in db: Database) throws {
        try db.execute(
                sql: """
                    INSERT INTO cake_designs
                    (id, name, notes, photo_reference, source_kind, originating_order_photo_id,
                    originating_order_id, source_name, source_url, tags_json, is_favorite, created_at_unix_time,
                    updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        notes = excluded.notes,
                        photo_reference = excluded.photo_reference,
                        source_kind = excluded.source_kind,
                        originating_order_photo_id = excluded.originating_order_photo_id,
                        originating_order_id = excluded.originating_order_id,
                        source_name = excluded.source_name,
                        source_url = excluded.source_url,
                        tags_json = excluded.tags_json,
                        is_favorite = excluded.is_favorite,
                        created_at_unix_time = excluded.created_at_unix_time,
                        updated_at_unix_time = excluded.updated_at_unix_time
                    """,
                arguments: arguments([
                    design.id,
                    design.name,
                    design.notes,
                    design.photoReference,
                    design.sourceKind.rawValue,
                    design.originatingOrderPhotoId,
                    design.originatingOrderId,
                    design.sourceName,
                    design.sourceURL,
                    designTagsJSON(design.tags),
                    design.isFavorite,
                    design.createdAt.timeIntervalSince1970,
                    design.updatedAt.timeIntervalSince1970
                ])
        )
    }

    func fetchCakeDesign(id: String) throws -> CakeDesign? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM cake_designs WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return try cakeDesign(from: row)
        }
    }

    func fetchCakeDesign(originatingOrderPhotoId: String) throws -> CakeDesign? {
        try writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM cake_designs WHERE originating_order_photo_id = ?",
                arguments: [originatingOrderPhotoId]
            ) else { return nil }
            return try cakeDesign(from: row)
        }
    }

    func fetchCakeDesigns() throws -> [CakeDesign] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM cake_designs
                    ORDER BY lower(name), name
                    """
            ).map { try cakeDesign(from: $0) }
        }
    }

    func fetchCakeDesigns(sourceKind: CakeDesignSourceKind) throws -> [CakeDesign] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM cake_designs
                    WHERE source_kind = ?
                    ORDER BY lower(name), name
                    """,
                arguments: [sourceKind.rawValue]
            ).map { try cakeDesign(from: $0) }
        }
    }

    func recipeIngredients(recipeId: String, in db: Database) throws -> [RecipeIngredient] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT recipe_ingredients.*
                FROM recipe_ingredients
                INNER JOIN recipe_components
                ON recipe_components.id = recipe_ingredients.component_id
                WHERE recipe_components.recipe_id = ?
                ORDER BY recipe_components.sort_order ASC,
                         recipe_ingredients.created_at_unix_time ASC,
                         recipe_ingredients.id
                """,
            arguments: [recipeId]
        ).compactMap { row in
            guard let unit = InventoryUnit(rawValue: row["unit"]) else {
                return nil
            }

            return recipeIngredient(from: row, unit: unit)
        }
    }
}
