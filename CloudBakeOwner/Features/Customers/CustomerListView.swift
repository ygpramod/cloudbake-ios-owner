import SwiftUI
import UIKit

struct CustomerListView: View {
    @StateObject private var viewModel: CustomerListViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.navigateToAppDestination) private var navigate
    @EnvironmentObject private var orderNavigationRouter: OrderNavigationRouter
    @State private var isAddingCustomer = false
    @State private var isViewingCustomer = false
    @State private var isChoosingAddMode = false
    @State private var isImportingContact = false
    @State private var canOpenWhatsApp = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: CustomerListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        customerList
        .accessibilityIdentifier(AppDestination.customers.screenAccessibilityIdentifier)
        .cloudBakeCenteredPopup(
            isPresented: isChoosingAddMode,
            title: "Add Customer",
            subtitle: "Choose how to start this customer record",
            systemImage: "person.badge.plus",
            cancelAccessibilityIdentifier: "customers.add.cancel",
            onCancel: { isChoosingAddMode = false }
        ) {
            centeredPopupButton("Import From Contacts") {
                isChoosingAddMode = false
                isImportingContact = true
            }
            .accessibilityIdentifier("customers.add.importContacts")

            centeredPopupButton("Enter Manually") {
                isChoosingAddMode = false
                viewModel.beginAddingCustomer()
                isAddingCustomer = true
            }
            .accessibilityIdentifier("customers.add.manual")
        }
        .sheet(isPresented: $isImportingContact) {
            CustomerContactPicker { contact in
                let draft = CustomerContactDraftMapper().draft(from: contact)
                viewModel.beginAddingCustomer(importedDraft: draft)
                isImportingContact = false
                DispatchQueue.main.async {
                    isAddingCustomer = true
                }
            }
        }
        .sheet(isPresented: $isAddingCustomer, onDismiss: viewModel.cancelAddCustomer) {
            NavigationStack {
                CustomerForm(
                    viewModel: viewModel,
                    isPresented: $isAddingCustomer,
                    onCancel: viewModel.cancelAddCustomer,
                    onSave: viewModel.addCustomer
                )
            }
        }
        .sheet(isPresented: $isViewingCustomer, onDismiss: viewModel.closeCustomerDetail) {
            NavigationStack {
                CustomerDetailView(
                    viewModel: viewModel,
                    isPresented: $isViewingCustomer
                )
            }
        }
        .onAppear {
            viewModel.load()
            refreshWhatsAppAvailability()
        }
    }

    private var customerList: some View {
        CloudBakeScreenScaffold(
            title: "Customers",
            selectedDestination: .customers,
            primaryAction: CloudBakeScreenAction(
                title: "Add Customer",
                systemImage: "plus",
                accessibilityIdentifier: "customers.add",
                action: { isChoosingAddMode = true }
            )
        ) {
            if viewModel.customers.isEmpty {
                CloudBakeEmptyState(
                    title: "No customers yet",
                    systemImage: "person.2",
                    message: "Add customers before linking preferences and allergy notes to orders."
                )
            } else {
                CloudBakeSearchField(
                    text: $viewModel.searchText,
                    prompt: "Search customers",
                    accessibilityIdentifier: "customers.search",
                    isFocused: $isSearchFocused
                )

                customerResults
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            isSearchFocused = false
                        }
                    )
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "customers.error"
                )
            }
        }
    }

    @ViewBuilder
    private var customerResults: some View {
        if viewModel.visibleCustomers.isEmpty {
            CloudBakeEmptyState(
                title: "No matching customers",
                systemImage: "magnifyingglass",
                message: "Try another name, phone number, preference, allergy, or note."
            )
        } else {
            CloudBakeSection("Customers") {
                VStack(spacing: 16) {
                    ForEach(viewModel.visibleCustomers, id: \.id) { customer in
                        customerCard(customer)
                    }
                }
            }
        }
    }

    private func customerCard(_ customer: Customer) -> some View {
        let presentation = viewModel.presentation(for: customer)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                openCustomer(customer)
            } label: {
                HStack(spacing: CloudBakeTheme.Spacing.rowContent) {
                    CloudBakeCompactRowIcon(systemImage: "person.crop.circle", tint: .cloudBakeTeal)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(customer.name)
                            .font(CloudBakeTheme.Typography.rowTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(presentation.displayPhone)
                            .font(CloudBakeTheme.Typography.rowDetail)
                            .foregroundStyle(.secondary)

                        if let allergies = customer.allergies {
                            Label(allergies, systemImage: "exclamationmark.triangle")
                                .font(CloudBakeTheme.Typography.rowDetail.weight(.medium))
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(CloudBakeTheme.Typography.rowTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customers.item.\(customer.id)")

            HStack(spacing: 6) {
                if let phoneURL = viewModel.phoneURL(for: customer) {
                    CloudBakeAdaptiveActionButton(
                        title: "Call",
                        systemImage: "phone",
                        tint: .cloudBakeTeal,
                        accessibilityIdentifier: "customers.item.call.\(customer.id)",
                        isCompact: true
                    ) {
                        openURL(phoneURL)
                    }
                }

                if canOpenWhatsApp,
                   let messageURL = viewModel.whatsappMessageURL(for: customer) {
                    CloudBakeAdaptiveActionButton(
                        title: "WhatsApp",
                        systemImage: "message",
                        tint: .green,
                        accessibilityIdentifier: "customers.item.message.\(customer.id)",
                        isCompact: true
                    ) {
                        openURL(messageURL)
                    }
                }

                CloudBakeAdaptiveActionButton(
                    title: "New Order",
                    systemImage: "calendar.badge.plus",
                    tint: .cloudBakePink,
                    accessibilityIdentifier: "customers.item.newOrder.\(customer.id)",
                    isCompact: true
                ) {
                    orderNavigationRouter.beginNewOrder(customerId: customer.id)
                    navigate(.orders)
                }
            }
        }
        .padding(.horizontal, CloudBakeTheme.Spacing.cardPadding)
        .padding(.vertical, 14)
        .cloudBakeCardStyle()
    }

    private func openCustomer(_ customer: Customer) {
        viewModel.beginViewingCustomer(customer)
        isViewingCustomer = true
    }

    private func refreshWhatsAppAvailability() {
        canOpenWhatsApp = URL(string: "whatsapp://send")
            .map { UIApplication.shared.canOpenURL($0) } ?? false
    }
}
