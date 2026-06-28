import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            DashboardView()
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .accessibilityIdentifier("app.shell")
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .orders, .inventory, .recipes, .designs, .customers, .settings:
            PlaceholderScreen(destination: destination)
        }
    }
}

#Preview {
    RootView()
}
