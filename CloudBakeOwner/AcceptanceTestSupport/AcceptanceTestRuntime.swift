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
        environment["CLOUDBAKE_TEST_CELLULAR_BACKUP_CATCH_UP"] == "1"
    }

    static var usesCloudBackupSettingsFixture: Bool {
        environment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] == "1"
    }

    static var usesCloudRestoreFixture: Bool {
        environment["CLOUDBAKE_TEST_EMPTY_RESTORE"] == "1"
            || environment["CLOUDBAKE_TEST_CLOUD_RESTORE_SETTINGS"] == "1"
            || environment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] != nil
    }

    static var forcesIntroduction: Bool {
        environment["CLOUDBAKE_TEST_INTRODUCTION"] == "1"
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
    #else
    static let isRunning = false
    static let isXCTestProcess = false
    #endif
}
