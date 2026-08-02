import GRDB
import XCTest

@testable import CloudBakeOwner

final class StarterOrderTemplateMigrationTests: XCTestCase {
    func testMigrationSnapshotsCurrentOwnerReminderDefaults() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let migrator = AppDatabaseMigrations.makeMigrator()
        try migrator.migrate(queue, upTo: "0041_add_structured_order_requirements")
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE order_reminder_defaults
                    SET day_offsets_json = ?, includes_due_time = ?, updated_at_unix_time = ?
                    WHERE id = 1
                    """,
                arguments: ["[7,1]", false, 1_800_001_000]
            )
        }

        try migrator.migrate(queue)

        let templates = try GRDBCoreDataRepository(writer: queue).fetchOrderTemplates()
        let expected = try OrderReminderConfiguration(
            mode: .defaultSnapshot,
            dayOffsets: [7, 1],
            includesDueTime: false
        )
        XCTAssertEqual(templates.count, 6)
        XCTAssertTrue(templates.allSatisfy { $0.reminderConfiguration == expected })
    }

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

        let expectedValues = [
            (
                id: "starter-template-classic-birthday",
                occasion: "Birthday",
                tiers: "1",
                sponge: "Vanilla",
                filling: "Buttercream",
                frosting: "Buttercream",
                theme: nil as String?,
                packaging: "Standard Box"
            ),
            (
                id: "starter-template-chocolate-birthday",
                occasion: "Birthday",
                tiers: "1",
                sponge: "Chocolate",
                filling: "Chocolate Ganache",
                frosting: "Ganache",
                theme: nil,
                packaging: "Standard Box"
            ),
            (
                id: "starter-template-anniversary",
                occasion: "Anniversary",
                tiers: "1",
                sponge: "Vanilla",
                filling: "Fruit",
                frosting: "Buttercream",
                theme: "Elegant",
                packaging: "Standard Box"
            ),
            (
                id: "starter-template-baby-shower",
                occasion: "Baby Shower",
                tiers: "1",
                sponge: "Vanilla",
                filling: "Buttercream",
                frosting: "Buttercream",
                theme: "Baby Shower",
                packaging: "Standard Box"
            ),
            (
                id: "starter-template-floral-celebration",
                occasion: "Celebration",
                tiers: "1",
                sponge: "Vanilla",
                filling: "Fruit",
                frosting: "Buttercream",
                theme: "Floral",
                packaging: "Tall Box"
            ),
            (
                id: "starter-template-two-tier-wedding",
                occasion: "Wedding",
                tiers: "2",
                sponge: "Vanilla",
                filling: "Fruit",
                frosting: "Buttercream",
                theme: "Elegant",
                packaging: "Tall Box"
            ),
        ]

        for expected in expectedValues {
            let template = try XCTUnwrap(templates.first { $0.id == expected.id })
            XCTAssertEqual(template.cakeTitle, template.name)
            XCTAssertNil(template.cakeDesignId)
            XCTAssertNil(template.recipeId)
            XCTAssertEqual(template.recipeScaleMultiplier, 1)
            XCTAssertEqual(template.fulfillmentType, .pickup)
            XCTAssertNil(template.cakeNotes)
            XCTAssertNil(template.cakeMessage)
            XCTAssertEqual(template.reminderConfiguration, .initialDefault)
            XCTAssertEqual(template.cakeSpecification.occasion, expected.occasion)
            XCTAssertNil(template.cakeSpecification.servings)
            XCTAssertNil(template.cakeSpecification.size)
            XCTAssertNil(template.cakeSpecification.weightKilograms)
            XCTAssertEqual(template.cakeSpecification.shape, "Circle")
            XCTAssertEqual(template.cakeSpecification.tiers, expected.tiers)
            XCTAssertEqual(template.cakeSpecification.spongeFlavour, expected.sponge)
            XCTAssertEqual(template.cakeSpecification.filling, expected.filling)
            XCTAssertEqual(template.cakeSpecification.frosting, expected.frosting)
            XCTAssertNil(template.cakeSpecification.colourPalette)
            XCTAssertEqual(template.cakeSpecification.theme, expected.theme)
            XCTAssertEqual(template.cakeSpecification.topperRequirements, "None")
            XCTAssertEqual(template.cakeSpecification.candlesAndAccessories, "None")
            XCTAssertEqual(template.cakeSpecification.packaging, expected.packaging)
            XCTAssertTrue(template.extraIngredients.isEmpty)
            XCTAssertTrue(template.checklistItems.isEmpty)
        }
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
