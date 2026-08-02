import GRDB
import XCTest

@testable import CloudBakeOwner

final class StarterOrderTemplateMigrationTests: XCTestCase {
    func testMigrationSeedsStarterCatalogueOnceWithStructuredRequirements() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0041_add_structured_order_requirements")

        try migrator.migrate(queue)
        try migrator.migrate(queue)

        let templates = try GRDBCoreDataRepository(writer: queue).fetchOrderTemplates()
        XCTAssertEqual(
            templates.map(\.name),
            [
                "Anniversary Cake",
                "Baby Shower Cake",
                "Chocolate Birthday Cake",
                "Classic Birthday Cake",
                "Floral Celebration Cake",
                "Two-Tier Wedding Cake",
            ]
        )

        let wedding = try XCTUnwrap(
            templates.first { $0.id == "starter-template-two-tier-wedding" }
        )
        XCTAssertEqual(wedding.cakeTitle, "Two-Tier Wedding Cake")
        XCTAssertEqual(wedding.fulfillmentType, .pickup)
        XCTAssertEqual(wedding.reminderConfiguration, .initialDefault)
        XCTAssertEqual(wedding.cakeSpecification.occasion, "Wedding")
        XCTAssertEqual(wedding.cakeSpecification.shape, "Circle")
        XCTAssertEqual(wedding.cakeSpecification.tiers, "2")
        XCTAssertEqual(wedding.cakeSpecification.spongeFlavour, "Vanilla")
        XCTAssertEqual(wedding.cakeSpecification.filling, "Fruit")
        XCTAssertEqual(wedding.cakeSpecification.frosting, "Buttercream")
        XCTAssertEqual(wedding.cakeSpecification.theme, "Elegant")
        XCTAssertEqual(wedding.cakeSpecification.packaging, "Tall Box")
        XCTAssertTrue(wedding.extraIngredients.isEmpty)
        XCTAssertTrue(wedding.checklistItems.isEmpty)
    }

    func testDeletedAndRenamedStarterTemplatesAreNotRecreated() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue)
        let repository = GRDBCoreDataRepository(writer: queue)
        let anniversary = try XCTUnwrap(
            repository.fetchOrderTemplates().first {
                $0.id == "starter-template-anniversary"
            }
        )
        let renamed = OrderTemplate(
            id: anniversary.id,
            name: "Our Anniversary Cake",
            cakeTitle: anniversary.cakeTitle,
            cakeDesignId: anniversary.cakeDesignId,
            recipeId: anniversary.recipeId,
            recipeScaleMultiplier: anniversary.recipeScaleMultiplier,
            fulfillmentType: anniversary.fulfillmentType,
            cakeNotes: anniversary.cakeNotes,
            cakeMessage: anniversary.cakeMessage,
            cakeSpecification: anniversary.cakeSpecification,
            reminderConfiguration: anniversary.reminderConfiguration,
            extraIngredients: anniversary.extraIngredients,
            checklistItems: anniversary.checklistItems,
            createdAt: anniversary.createdAt,
            updatedAt: anniversary.updatedAt.addingTimeInterval(60)
        )

        try repository.save(renamed)
        try repository.deleteOrderTemplate(id: "starter-template-baby-shower")
        try migrator.migrate(queue)

        let reloaded = try GRDBCoreDataRepository(writer: queue).fetchOrderTemplates()
        XCTAssertEqual(reloaded.count, 5)
        XCTAssertEqual(
            reloaded.first { $0.id == anniversary.id }?.name,
            "Our Anniversary Cake"
        )
        XCTAssertFalse(reloaded.contains { $0.id == "starter-template-baby-shower" })
    }
}
