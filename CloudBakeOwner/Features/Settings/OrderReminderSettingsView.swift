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

@MainActor
final class PaymentReminderSettingsViewModel: ObservableObject {
    @Published var reminderTime: Date
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let repository: PaymentReminderConfigurationRepository
    private let dateProvider: () -> Date
    private let calendar: Calendar
    private let onSaved: () -> Void

    init(
        repository: PaymentReminderConfigurationRepository,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        onSaved: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.onSaved = onSaved
        reminderTime = dateProvider()
    }

    func load() {
        do {
            apply(try repository.fetchPaymentReminderConfiguration())
            errorMessage = nil
        } catch {
            errorMessage = "Payment reminder time could not be loaded."
        }
    }

    @discardableResult
    func save() -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        do {
            let configuration = try PaymentReminderConfiguration(
                hour: components.hour ?? 9,
                minute: components.minute ?? 0
            )
            try repository.savePaymentReminderConfiguration(
                configuration,
                updatedAt: dateProvider()
            )
            apply(configuration)
            statusMessage = "Daily payment reminders will arrive at \(formattedTime)."
            errorMessage = nil
            onSaved()
            return true
        } catch {
            statusMessage = nil
            errorMessage = "Payment reminder time could not be saved."
            return false
        }
    }

    var formattedTime: String {
        reminderTime.formatted(date: .omitted, time: .shortened)
    }

    private func apply(_ configuration: PaymentReminderConfiguration) {
        let referenceDate = dateProvider()
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = configuration.hour
        components.minute = configuration.minute
        reminderTime = calendar.date(from: components) ?? referenceDate
    }
}

struct OrderReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OrderReminderSettingsViewModel
    @ObservedObject var paymentViewModel: PaymentReminderSettingsViewModel

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

            CloudBakeSection("Payment Follow-up") {
                CloudBakeDetailCard {
                    DatePicker(
                        "Daily reminder time",
                        selection: $paymentViewModel.reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("settings.paymentReminders.time")
                }
            }

            Text("After a completed order is due, CloudBake sends one daily reminder while its balance remains unpaid.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage = paymentViewModel.statusMessage {
                CloudBakeDetailCard {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .accessibilityIdentifier("settings.paymentReminders.status")
            }
            if let errorMessage = paymentViewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "settings.paymentReminders.error"
                )
            }

            Button("Save Payment Reminder Time") {
                paymentViewModel.save()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cloudBakePink, in: Capsule())
            .accessibilityIdentifier("settings.paymentReminders.save")
        }
        .accessibilityIdentifier("screen.settings.orderReminders")
        .task {
            viewModel.load()
            paymentViewModel.load()
        }
    }
}
