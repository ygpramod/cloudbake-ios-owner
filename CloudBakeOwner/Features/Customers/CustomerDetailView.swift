import SwiftUI

struct CustomerDetailView: View {
    @ObservedObject var viewModel: CustomerListViewModel
    @Binding var isPresented: Bool
    let showsDoneButton: Bool
    @State private var isEditingCustomer = false

    init(
        viewModel: CustomerListViewModel,
        isPresented: Binding<Bool>,
        showsDoneButton: Bool = true
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        CloudBakeDetailScaffold(
            title: viewModel.selectedCustomer?.name ?? "Customer",
            showsBackButton: showsDoneButton,
            backAccessibilityIdentifier: "customers.detail.done",
            primaryAction: CloudBakeDetailAction(
                title: "Edit",
                systemImage: "pencil",
                accessibilityIdentifier: "customers.detail.edit",
                action: {
                    viewModel.beginEditingCustomer()
                    isEditingCustomer = true
                }
            ),
            onBack: {
                isPresented = false
            }
        ) {
            if let customer = viewModel.selectedCustomer {
                CloudBakeHeroCard(systemImage: "person.crop.circle", tint: .cloudBakeTeal) {
                    Text("Customer")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakeTeal)

                    Text(customer.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(customer.phone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CloudBakeSection("Contact") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Name") {
                            Text(customer.name)
                        }
                        CloudBakeDetailDivider()
                        CloudBakeDetailRow("Phone") {
                            Text(customer.phone)
                        }
                        if let email = customer.email {
                            CloudBakeDetailDivider()
                            CloudBakeDetailRow("Email") {
                                Text(email)
                            }
                        }
                        if let address = customer.address {
                            CloudBakeDetailDivider()
                            CloudBakeDetailRow("Address") {
                                Text(address)
                            }
                        }
                    }
                }

                if !viewModel.selectedCustomerImportantDates.isEmpty {
                    CloudBakeSection("Important Dates") {
                        CloudBakeDetailCard {
                        ForEach(viewModel.selectedCustomerImportantDates, id: \.id) { importantDate in
                            CloudBakeDetailRow(importantDate.label) {
                                Text(importantDate.date.formatted(date: .abbreviated, time: .omitted))
                            }
                            if importantDate.id != viewModel.selectedCustomerImportantDates.last?.id {
                                CloudBakeDetailDivider()
                            }
                        }
                        }
                    }
                }

                if customer.hasDetailPreferences {
                    CloudBakeSection("Preferences") {
                        CloudBakeDetailCard {
                            customerPreferenceRow("Likes", value: customer.likes)
                            customerPreferenceRow("Dislikes", value: customer.dislikes)
                            customerPreferenceRow("Allergies", value: customer.allergies, tint: .red)
                            customerPreferenceRow("Dietary Restrictions", value: customer.dietaryRestrictions)
                            customerPreferenceRow("Notes", value: customer.notes)
                        }
                    }
                }

                CloudBakeSection("Orders") {
                    CloudBakeDetailCard {
                    if viewModel.selectedCustomerOrders.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.cloudBakePink)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.cloudBakePink.opacity(0.10)))
                            Text("No linked orders yet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("customers.detail.noOrders")
                            Spacer()
                        }
                        .padding(.vertical, 14)
                    } else {
                        ForEach(viewModel.selectedCustomerOrders, id: \.id) { order in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(order.title)
                                    .font(.headline)
                                    .accessibilityIdentifier("customers.detail.order.title.\(order.id)")

                                HStack {
                                    Text(order.dueAt.formatted(date: .abbreviated, time: .shortened))
                                    Text(order.status.displayName)
                                    Text(order.fulfillmentType.displayName)
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .accessibilityIdentifier("customers.detail.order.\(order.id)")

                            if order.id != viewModel.selectedCustomerOrders.last?.id {
                                CloudBakeDetailDivider()
                            }
                        }
                    }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    CloudBakeErrorBanner(
                        message: errorMessage,
                        accessibilityIdentifier: "customers.detail.error"
                    )
                }
            }
        }
        .sheet(isPresented: $isEditingCustomer, onDismiss: viewModel.cancelEditingCustomer) {
            NavigationStack {
                CustomerForm(
                    title: "Edit Customer",
                    viewModel: viewModel,
                    isPresented: $isEditingCustomer,
                    showsImportantDate: false,
                    onCancel: viewModel.cancelEditingCustomer,
                    onSave: viewModel.saveEditedCustomer
                )
            }
        }
    }

    @ViewBuilder
    private func customerPreferenceRow(_ title: String, value: String?, tint: Color = .secondary) -> some View {
        if let value {
            CloudBakeDetailRow(title) {
                Text(value)
                    .foregroundStyle(tint)
            }
            if title != "Notes" {
                CloudBakeDetailDivider()
            }
        }
    }
}

private extension Customer {
    var hasDetailPreferences: Bool {
        [likes, dislikes, allergies, dietaryRestrictions, notes]
            .contains { value in
                guard let value else {
                    return false
                }

                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }
}
