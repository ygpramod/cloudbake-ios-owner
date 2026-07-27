import Foundation

enum AcceptanceTestRuntime {
    #if DEBUG
    private static var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    static var isRunning: Bool {
        isRunning(environment: environment)
    }

    static var isXCTestProcess: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    static var usesAutomaticCellularBackupFixture: Bool {
        isEnabled("CLOUDBAKE_TEST_CELLULAR_BACKUP_CATCH_UP", environment: environment)
    }

    static var usesCloudBackupSettingsFixture: Bool {
        isEnabled("CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS", environment: environment)
    }

    static var usesCloudRestoreFixture: Bool {
        usesCloudRestoreFixture(environment: environment)
    }

    static func usesCloudRestoreFixture(environment: [String: String]) -> Bool {
        guard isRunning(environment: environment) else {
            return false
        }
        return environment["CLOUDBAKE_TEST_EMPTY_RESTORE"] == "1"
            || environment["CLOUDBAKE_TEST_CLOUD_RESTORE_SETTINGS"] == "1"
            || environment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] != nil
    }

    static var forcesIntroduction: Bool {
        isEnabled("CLOUDBAKE_TEST_INTRODUCTION", environment: environment)
    }

    static var opensManualOrderCustomerEntryDirectly: Bool {
        isEnabled(
            "CLOUDBAKE_TEST_DIRECT_ORDER_CUSTOMER_ENTRY",
            environment: environment
        )
    }

    static var initialDestination: AppDestination? {
        guard isRunning,
              let rawDestination = environment["CLOUDBAKE_INITIAL_DESTINATION"],
              let destination = AppDestination(rawValue: rawDestination),
              destination != .dashboard else {
            return nil
        }
        return destination
    }

    static func isRunning(environment: [String: String]) -> Bool {
        environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] == "1"
    }

    static func isEnabled(_ key: String, environment: [String: String]) -> Bool {
        isRunning(environment: environment) && environment[key] == "1"
    }
    #else
    static let isRunning = false
    static let isXCTestProcess = false
    static let opensManualOrderCustomerEntryDirectly = false
    #endif
}
