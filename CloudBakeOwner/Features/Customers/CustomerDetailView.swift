import SwiftUI

struct CustomerDetailView: View {
    @ObservedObject var viewModel: CustomerListViewModel
    @Binding var isPresented: Bool
    let showsDoneButton: Bool
    @Environment(\.navigateToAppDestination) private var navigate
    @State private var isEditingCustomer = false
    @State private var isConfirmingDelete = false

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
            secondaryActions: [
                CloudBakeDetailAction(
                    title: "Delete",
                    systemImage: "trash",
                    accessibilityIdentifier: "customers.detail.delete",
                    action: {
                        isConfirmingDelete = true
                    }
                )
            ],
            onBack: {
                isPresented = false
            }
        ) {
            if let customer = viewModel.selectedCustomer {
                let presentation = viewModel.presentation(for: customer)

                CloudBakeHeroCard(systemImage: "person.crop.circle", tint: .cloudBakeTeal) {
                    Text("Customer")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.cloudBakeTeal)

                    Text(customer.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(presentation.displayPhone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CloudBakeSection("Actions") {
                    CloudBakeDetailCard {
                        HStack(spacing: 12) {
                            if let phoneURL = viewModel.phoneURL(for: customer) {
                                Link(destination: phoneURL) {
                                    Label("Call", systemImage: "phone")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.cloudBakeTeal)
                                .accessibilityIdentifier("customers.detail.call")
                            }

                            if let messageURL = viewModel.messageURL(for: customer) {
                                Link(destination: messageURL) {
                                    Label("Message", systemImage: "message")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.cloudBakePink)
                                .accessibilityIdentifier("customers.detail.message")
                            }
                        }

                        Button {
                            isPresented = false
                            navigate(.orders)
                        } label: {
                            Label("New Order", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cloudBakePink)
                        .accessibilityIdentifier("customers.detail.newOrder")
                    }
                }

                CloudBakeSection("Contact") {
                    CloudBakeDetailCard {
                        CloudBakeDetailRow("Phone") {
                            Text(presentation.displayPhone)
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

                if customer.hasSafetyNotes {
                    CloudBakeSection("Allergies & Dietary") {
                        CloudBakeDetailCard {
                            if let allergies = customer.allergies {
                                safetyRow("Allergies", value: allergies, systemImage: "exclamationmark.triangle.fill")
                            }

                            if customer.allergies != nil, customer.dietaryRestrictions != nil {
                                CloudBakeDetailDivider()
                            }

                            if let dietaryRestrictions = customer.dietaryRestrictions {
                                safetyRow("Dietary Restrictions", value: dietaryRestrictions, systemImage: "fork.knife.circle.fill")
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
        .cloudBakeCenteredPopup(
            isPresented: isConfirmingDelete,
            title: "Delete Customer?",
            subtitle: "Delete this customer record. Existing orders keep their customer name snapshot.",
            systemImage: "trash",
            cancelAccessibilityIdentifier: "customers.delete.cancel",
            onCancel: { isConfirmingDelete = false }
        ) {
            if let customer = viewModel.selectedCustomer {
                centeredPopupButton("Delete \(customer.name)", role: .destructive) {
                    if viewModel.deleteSelectedCustomer() {
                        isConfirmingDelete = false
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("customers.delete.confirm")
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

    private func safetyRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(CloudBakeTheme.Typography.metadata.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.orange)

                Text(value)
                    .font(CloudBakeTheme.Typography.rowTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("customers.detail.safety.\(title)")
    }
}

private extension Customer {
    var hasDetailPreferences: Bool {
        [likes, dislikes, notes].contains { value in
            guard let value else {
                return false
            }

            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var hasSafetyNotes: Bool {
        [allergies, dietaryRestrictions]
            .contains { value in
                guard let value else {
                    return false
                }

                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }
}
