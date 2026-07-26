import XCTest
@testable import CloudBakeOwner

final class AppDestinationTests: XCTestCase {
    func testPrimaryNavigationDestinationsAreInExpectedOrder() {
        XCTAssertEqual(
            AppDestination.allCases.map(\.title),
            ["Dashboard", "Orders", "Inventory", "More", "Recipes", "Designs", "Reminders", "Reports", "Customers", "Settings"]
        )
    }

    func testDestinationsHaveStableAccessibilityIdentifiers() {
        for destination in AppDestination.allCases {
            XCTAssertEqual(destination.accessibilityIdentifier, "navigation.\(destination.rawValue)")
            XCTAssertEqual(destination.screenAccessibilityIdentifier, "screen.\(destination.rawValue)")
        }
    }

    func testSecondaryDestinationsAreGroupedUnderMore() {
        XCTAssertEqual(
            AppDestination.allCases.filter(\.isGroupedUnderMore).map(\.title),
            ["Recipes", "Designs", "Reminders", "Reports", "Customers", "Settings"]
        )
    }

    func testAcceptanceRuntimeRequiresExplicitInMemoryDatabaseFlag() throws {
        XCTAssertFalse(AcceptanceTestRuntime.isRunning(environment: [:]))
        XCTAssertFalse(
            AcceptanceTestRuntime.isRunning(
                environment: ["CLOUDBAKE_SEED_CUSTOMER_FIXTURE": "1"]
            )
        )
        XCTAssertTrue(
            AcceptanceTestRuntime.isRunning(
                environment: ["CLOUDBAKE_USE_IN_MEMORY_DATABASE": "1"]
            )
        )
        XCTAssertNil(
            try AcceptanceTestDatabaseFixtures.openIfRequested(
                environment: ["CLOUDBAKE_SEED_CUSTOMER_FIXTURE": "1"]
            )
        )
    }

    func testAcceptanceOverridesRequireExplicitInMemoryDatabaseFlag() {
        let fixtureOnly = ["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS": "1"]
        let acceptanceFixture = [
            "CLOUDBAKE_USE_IN_MEMORY_DATABASE": "1",
            "CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS": "1"
        ]

        XCTAssertFalse(
            AcceptanceTestRuntime.isEnabled(
                "CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS",
                environment: fixtureOnly
            )
        )
        XCTAssertTrue(
            AcceptanceTestRuntime.isEnabled(
                "CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS",
                environment: acceptanceFixture
            )
        )
        XCTAssertFalse(
            AcceptanceTestRuntime.usesCloudRestoreFixture(
                environment: ["CLOUDBAKE_TEST_EMPTY_RESTORE": "1"]
            )
        )
        XCTAssertTrue(
            AcceptanceTestRuntime.usesCloudRestoreFixture(
                environment: [
                    "CLOUDBAKE_USE_IN_MEMORY_DATABASE": "1",
                    "CLOUDBAKE_TEST_EMPTY_RESTORE": "1"
                ]
            )
        )
    }

    func testAcceptanceDatabaseUsesInjectedEnvironmentForSeeding() throws {
        let database = try XCTUnwrap(
            AcceptanceTestDatabaseFixtures.openIfRequested(
                environment: [
                    "CLOUDBAKE_USE_IN_MEMORY_DATABASE": "1",
                    "CLOUDBAKE_SEED_CUSTOMER_FIXTURE": "1"
                ]
            )
        )

        let customers = try database.makeCoreDataRepository().fetchCustomers()
        XCTAssertEqual(customers.map(\.name), ["Amy"])
    }

    func testReservationRepairRunnerDrainsFullBatchesAndStopsAfterPartialBatch() async throws {
        let repository = FakeReservationRepairRepository(
            summaries: [
                OrderInventoryReservationRepairSummary(
                    completedCount: 50,
                    failedCount: 0,
                    hasMore: true
                ),
                OrderInventoryReservationRepairSummary(
                    completedCount: 49,
                    failedCount: 1,
                    hasMore: true
                ),
                OrderInventoryReservationRepairSummary(
                    completedCount: 2,
                    failedCount: 0
                )
            ]
        )
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        let summary = try await OrderInventoryReservationRepairRunner(
            repository: repository,
            dateProvider: { timestamp },
            activationIdProvider: { "activation-1" }
        ).run()

        XCTAssertEqual(
            summary,
            OrderInventoryReservationRepairSummary(
                completedCount: 101,
                failedCount: 1
            )
        )
        XCTAssertEqual(repository.requestedLimits, [50, 50, 50])
        XCTAssertEqual(repository.requestedDates, [timestamp, timestamp, timestamp])
        XCTAssertEqual(repository.requestedActivationIds, ["activation-1", "activation-1", "activation-1"])
        XCTAssertFalse(summary.hasMore)
    }

    func testReservationRepairRunnerHonorsMaximumBatchCount() async throws {
        let repository = FakeReservationRepairRepository(
            summaries: Array(
                repeating: OrderInventoryReservationRepairSummary(
                    completedCount: 50,
                    failedCount: 0,
                    hasMore: true
                ),
                count: 3
            )
        )

        let summary = try await OrderInventoryReservationRepairRunner(
            repository: repository,
            maximumBatchCount: 2,
            activationIdProvider: { "activation-2" }
        ).run()

        XCTAssertEqual(summary.completedCount, 100)
        XCTAssertEqual(repository.requestedLimits, [50, 50])
        XCTAssertTrue(summary.hasMore)
    }
}

private final class FakeReservationRepairRepository:
    OrderInventoryReservationMutationRepository {
    var summaries: [OrderInventoryReservationRepairSummary]
    var requestedLimits: [Int] = []
    var requestedDates: [Date] = []
    var requestedActivationIds: [String] = []

    init(summaries: [OrderInventoryReservationRepairSummary]) {
        self.summaries = summaries
    }

    func saveOrder(
        _: Order,
        replacingExtraIngredients _: [OrderExtraIngredient],
        allowInventoryShortage _: Bool
    ) throws {}

    func repairOrderInventoryReservations(
        limit: Int,
        at timestamp: Date,
        activationId: String
    ) throws -> OrderInventoryReservationRepairSummary {
        requestedLimits.append(limit)
        requestedDates.append(timestamp)
        requestedActivationIds.append(activationId)
        guard !summaries.isEmpty else {
            return OrderInventoryReservationRepairSummary(
                completedCount: 0,
                failedCount: 0
            )
        }
        return summaries.removeFirst()
    }
}
