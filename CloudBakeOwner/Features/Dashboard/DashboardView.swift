import SwiftUI

struct DashboardView: View {
    var body: some View {
        List {
            Section("Today") {
                DashboardRow(title: "Upcoming orders", detail: "No orders yet")
                DashboardRow(title: "Low inventory", detail: "No alerts yet")
            }

            Section("Soon") {
                DashboardRow(title: "Reminders", detail: "Delivery reminders will appear here")
                DashboardRow(title: "Recent designs", detail: "Cake photos will appear here")
            }

            Section("Areas") {
                ForEach(AppDestination.allCases.filter { $0 != .dashboard }) { destination in
                    NavigationLink(value: destination) {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
                    .accessibilityIdentifier(destination.accessibilityIdentifier)
                }
            }
        }
        .navigationTitle("CloudBake")
        .accessibilityIdentifier(AppDestination.dashboard.screenAccessibilityIdentifier)
    }
}

private struct DashboardRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
}
