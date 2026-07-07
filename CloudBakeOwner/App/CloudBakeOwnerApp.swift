import SwiftUI

@main
struct CloudBakeOwnerApp: App {
    private let database = Result {
        try AppDatabase.openConfigured()
    }

    var body: some Scene {
        WindowGroup {
            switch database {
            case .success(let database):
                RootView(database: database)
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
