import SwiftUI

@MainActor
final class OrderReminderSettingsViewModel: ObservableObject {
    @Published var dayOffsetsText = ""
    @Published var includesDueTime = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let repository: OrderReminderConfigurationRepository
    private let dateProvider: () -> Date

    init(
        repository: OrderReminderConfigurationRepository,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
    }

    func load() {
        do {
            apply(try repository.fetchDefaultOrderReminderConfiguration())
            errorMessage = nil
        } catch {
            errorMessage = "Order reminder defaults could not be loaded."
        }
    }

    @discardableResult
    func save() -> Bool {
        do {
            let configuration = try OrderReminderDraftValidation.configuration(
                mode: .useDefaults,
                dayOffsetsText: dayOffsetsText,
                includesDueTime: includesDueTime
            )
            try repository.saveDefaultOrderReminderConfiguration(
                configuration,
                updatedAt: dateProvider()
            )
            apply(configuration)
            statusMessage = "New orders will use these reminder defaults."
            errorMessage = nil
            return true
        } catch let error as OrderDraftValidationError {
            statusMessage = nil
            errorMessage = error.message
            return false
        } catch {
            statusMessage = nil
            errorMessage = "Order reminder defaults could not be saved."
            return false
        }
    }

    private func apply(_ configuration: OrderReminderConfiguration) {
        dayOffsetsText = configuration.dayOffsets.map(String.init).joined(separator: ", ")
        includesDueTime = configuration.includesDueTime
    }

}

struct OrderReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OrderReminderSettingsViewModel

    var body: some View {
        CloudBakeDetailScaffold(
            title: "Order Reminders",
            backAccessibilityIdentifier: "settings.orderReminders.back",
            onBack: { dismiss() }
        ) {
            CloudBakeSection("Defaults for New Orders") {
                CloudBakeDetailCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Days Before")
                            .font(.headline)
                        TextField("3, 2, 1", text: $viewModel.dayOffsetsText)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("settings.orderReminders.dayOffsets")
                        Text("Use unique whole days from 1 to 30, separated by commas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)

                    CloudBakeDetailDivider()

                    Toggle("Remind at the order due time", isOn: $viewModel.includesDueTime)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("settings.orderReminders.dueTime")
                }
            }

            Text("These defaults are copied when a new order is created. Existing orders keep their saved reminder plan.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage = viewModel.statusMessage {
                CloudBakeDetailCard {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .accessibilityIdentifier("settings.orderReminders.status")
            }
            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "settings.orderReminders.error"
                )
            }

            Button("Save Reminder Defaults") {
                viewModel.save()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cloudBakePink, in: Capsule())
            .accessibilityIdentifier("settings.orderReminders.save")
        }
        .accessibilityIdentifier("screen.settings.orderReminders")
        .task {
            viewModel.load()
        }
    }
}
