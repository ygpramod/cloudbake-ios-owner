#if DEBUG
import Foundation

enum AcceptanceTestDatabaseFixtures {
    static func openIfRequested(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AppDatabase? {
        guard AcceptanceTestRuntime.isRunning(environment: environment) else {
            return nil
        }

        let database = try AppDatabase.makeInMemory()
        try database.seedAcceptanceFixturesIfRequested()
        return database
    }
}
#endif
