import XCTest
@testable import CloudBakeOwner

@MainActor
final class OrderReminderSettingsViewModelTests: XCTestCase {
    func testPaymentReminderSettingsLoadAndSaveOwnerTime() throws {
        let repository = FakePaymentReminderSettingsRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 8)
        )!
        repository.configuration = try PaymentReminderConfiguration(hour: 9, minute: 15)
        var saveCallbackCount = 0
        let viewModel = PaymentReminderSettingsViewModel(
            repository: repository,
            dateProvider: { now },
            calendar: calendar,
            onSaved: { saveCallbackCount += 1 }
        )

        viewModel.load()
        XCTAssertEqual(
            calendar.dateComponents([.hour, .minute], from: viewModel.reminderTime),
            DateComponents(hour: 9, minute: 15)
        )

        viewModel.reminderTime = calendar.date(
            from: DateComponents(year: 2027, month: 2, day: 10, hour: 14, minute: 30)
        )!

        XCTAssertTrue(viewModel.save())
        XCTAssertEqual(
            repository.configuration,
            try PaymentReminderConfiguration(hour: 14, minute: 30)
        )
        XCTAssertEqual(repository.lastUpdatedAt, now)
        XCTAssertEqual(saveCallbackCount, 1)
        XCTAssertEqual(
            viewModel.statusMessage,
            "Daily payment reminders will arrive at \(viewModel.formattedTime)."
        )
    }

    func testLoadAndSaveNormalizeReminderDefaults() {
        let repository = FakeOrderReminderSettingsRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = OrderReminderSettingsViewModel(
            repository: repository,
            dateProvider: { timestamp }
        )

        viewModel.load()
        XCTAssertEqual(viewModel.dayOffsetsText, "3, 2, 1")
        XCTAssertTrue(viewModel.includesDueTime)

        viewModel.dayOffsetsText = "1, 7, 3"
        viewModel.includesDueTime = false

        XCTAssertTrue(viewModel.save())
        XCTAssertEqual(viewModel.dayOffsetsText, "7, 3, 1")
        XCTAssertEqual(
            repository.defaultConfiguration,
            try OrderReminderConfiguration(
                mode: .defaultSnapshot,
                dayOffsets: [7, 3, 1],
                includesDueTime: false
            )
        )
        XCTAssertEqual(repository.lastUpdatedAt, timestamp)
        XCTAssertEqual(
            viewModel.statusMessage,
            "New orders will use these reminder defaults."
        )
    }

    func testSaveRejectsMalformedDuplicateAndEmptySchedules() {
        let repository = FakeOrderReminderSettingsRepository()
        let viewModel = OrderReminderSettingsViewModel(repository: repository)

        viewModel.dayOffsetsText = "3, cake"
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(
            viewModel.errorMessage,
            "Enter reminder days as whole numbers separated by commas, for example 7, 3, 1."
        )

        viewModel.dayOffsetsText = "3, 3"
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(viewModel.errorMessage, "Enter each reminder day only once.")

        viewModel.dayOffsetsText = ""
        viewModel.includesDueTime = false
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(
            viewModel.errorMessage,
            "Add at least one reminder day or keep the due-time reminder on."
        )
        XCTAssertEqual(repository.saveCount, 0)
    }
}

private final class FakePaymentReminderSettingsRepository:
    PaymentReminderConfigurationRepository {
    var configuration = PaymentReminderConfiguration.initialDefault
    var lastUpdatedAt: Date?

    func fetchPaymentReminderConfiguration() throws -> PaymentReminderConfiguration {
        configuration
    }

    func savePaymentReminderConfiguration(
        _ configuration: PaymentReminderConfiguration,
        updatedAt: Date
    ) throws {
        self.configuration = configuration
        lastUpdatedAt = updatedAt
    }
}

private final class FakeOrderReminderSettingsRepository:
    OrderReminderConfigurationRepository {
    var defaultConfiguration = OrderReminderConfiguration.initialDefault
    var lastUpdatedAt: Date?
    var saveCount = 0

    func fetchDefaultOrderReminderConfiguration() throws -> OrderReminderConfiguration {
        defaultConfiguration
    }

    func saveDefaultOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        updatedAt: Date
    ) throws {
        defaultConfiguration = try configuration.snapshotAsDefault()
        lastUpdatedAt = updatedAt
        saveCount += 1
    }

    func fetchOrderReminderConfiguration(
        orderId _: String
    ) throws -> OrderReminderConfiguration? {
        nil
    }

    func fetchOrderReminderConfigurations(
        orderIds _: [String]
    ) throws -> [String: OrderReminderConfiguration] {
        [:]
    }

    func saveOrderReminderConfiguration(
        _ configuration: OrderReminderConfiguration,
        orderId: String,
        updatedAt: Date
    ) throws {}
}
