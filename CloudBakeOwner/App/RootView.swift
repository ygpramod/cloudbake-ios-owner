import SwiftUI

struct RootView: View {
    let database: AppDatabase
    @StateObject private var expiryReminderViewModel: InAppExpiryReminderViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(database: AppDatabase) {
        self.database = database
        _expiryReminderViewModel = StateObject(
            wrappedValue: InAppExpiryReminderViewModel(
                repository: database.makeCoreDataRepository()
            )
        )
    }

    var body: some View {
        NavigationStack {
            DashboardView(
                viewModel: DashboardViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .accessibilityIdentifier("app.shell")
        .task {
            await refreshExpiryReminders()
            expiryReminderViewModel.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshExpiryReminders()
                expiryReminderViewModel.refresh()
            }
        }
        .sheet(item: Binding(
            get: { expiryReminderViewModel.currentReminder },
            set: { reminder in
                if reminder == nil {
                    expiryReminderViewModel.dismissCurrentReminder()
                }
            }
        )) { reminder in
            InAppExpiryReminderView(
                reminder: reminder,
                viewModel: expiryReminderViewModel
            )
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView(
                viewModel: DashboardViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .inventory:
            InventoryListView(
                viewModel: InventoryListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        case .orders, .recipes, .designs, .customers, .settings:
            PlaceholderScreen(destination: destination)
        }
    }

    private func refreshExpiryReminders() async {
        guard ProcessInfo.processInfo.environment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] != "1" else {
            return
        }

        await ExpiryReminderScheduler(
            repository: database.makeCoreDataRepository()
        ).refreshReminders()
    }
}

private struct InAppExpiryReminderView: View {
    let reminder: InAppExpiryReminder
    @ObservedObject var viewModel: InAppExpiryReminderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(reminder.isExpired ? "Expired Stock" : "Expiring This Week") {
                    LabeledContent("Item", value: reminder.itemName)
                    LabeledContent("Quantity", value: reminder.quantityText)
                    LabeledContent("Expiry", value: reminder.expiresAt.formatted(date: .abbreviated, time: .omitted))
                }

                Section("Snooze") {
                    Picker("Remind Me Again", selection: $viewModel.selectedSnoozeDays) {
                        ForEach(viewModel.snoozeDayOptions, id: \.self) { days in
                            Text(days == 1 ? "1 Day" : "\(days) Days").tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("expiryReminder.snoozeDays")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("expiryReminder.error")
                    }
                }
            }
            .navigationTitle("Expiry Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.dismissCurrentReminder()
                        dismiss()
                    }
                    .accessibilityIdentifier("expiryReminder.close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Snooze") {
                        viewModel.snoozeCurrentReminder()
                        dismiss()
                    }
                    .accessibilityIdentifier("expiryReminder.snooze")
                }
            }
        }
    }
}

#Preview {
    if let database = try? AppDatabase.makeInMemory() {
        RootView(database: database)
    } else {
        ContentUnavailableView(
            "CloudBake cannot open",
            systemImage: "exclamationmark.triangle",
            description: Text("The preview database could not be prepared.")
        )
    }
}
