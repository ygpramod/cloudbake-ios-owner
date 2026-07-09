import SwiftUI

@main
struct CloudBakeOwnerApp: App {
    private let database = Result {
        try AppDatabase.openConfigured()
    }
    @StateObject private var orderNotificationRouter = OrderNotificationRouter()
    @StateObject private var inventoryNavigationRouter = InventoryNavigationRouter()

    var body: some Scene {
        WindowGroup {
            switch database {
            case .success(let database):
                RootView(database: database)
                    .environmentObject(orderNotificationRouter)
                    .environmentObject(inventoryNavigationRouter)
                    .preferredColorScheme(.light)
                    .onAppear {
                        orderNotificationRouter.configureNotificationCenter()
                    }
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
