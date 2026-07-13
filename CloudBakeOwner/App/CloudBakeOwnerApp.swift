import SwiftUI
import os

@main
struct CloudBakeOwnerApp: App {
    private let database: Result<AppDatabase, Error>
    private let cloudBackupRuntime: CloudBackupRuntime?
    @StateObject private var orderNotificationRouter = OrderNotificationRouter()
    @StateObject private var orderNavigationRouter = OrderNavigationRouter()
    @StateObject private var inventoryNavigationRouter = InventoryNavigationRouter()

    init() {
        let database = Result { try AppDatabase.openConfigured() }
        self.database = database

        #if DEBUG
        if ProcessInfo.processInfo.environment["CLOUDBAKE_TEST_CELLULAR_BACKUP_CATCH_UP"] == "1" {
            cloudBackupRuntime = CloudBackupRuntime.automaticCellularUITestFixture()
            return
        }
        #endif

        guard ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] != "1",
              case .success(let appDatabase) = database else {
            cloudBackupRuntime = nil
            return
        }

        do {
            let runtime = try CloudBackupRuntime.live(database: appDatabase)
            cloudBackupRuntime = runtime
            if !runtime.registerBackgroundTask() {
                Logger.cloudBackup.error("Cloud backup background task registration failed")
            }
        } catch {
            cloudBackupRuntime = nil
            Logger.cloudBackup.error("Cloud backup runtime initialization failed")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch database {
            case .success(let database):
                RootView(
                    database: database,
                    cloudBackupRuntime: cloudBackupRuntime
                )
                    .environmentObject(orderNotificationRouter)
                    .environmentObject(orderNavigationRouter)
                    .environmentObject(inventoryNavigationRouter)
                    .preferredColorScheme(.light)
            case .failure:
                ContentUnavailableView(
                    "CloudBake cannot open",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The local database could not be prepared.")
                )
                .preferredColorScheme(.light)
            }
        }
    }
}

private extension Logger {
    static let cloudBackup = Logger(
        subsystem: "com.cloudbake.owner",
        category: "CloudBackup"
    )
}
