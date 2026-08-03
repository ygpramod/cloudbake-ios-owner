import GRDB

extension GRDBCoreDataRepository {
    func saveRecipeAggregate(
        recipe: Recipe,
        components: [RecipeComponent],
        ingredients: [RecipeIngredient]
    ) throws {
        try writer.write { db in
            try save(recipe, in: db)
            for component in components {
                try persistRecipeComponent(component, in: db)
            }
            for ingredient in ingredients {
                try persistRecipeIngredient(ingredient, in: db)
            }
        }
    }
}
