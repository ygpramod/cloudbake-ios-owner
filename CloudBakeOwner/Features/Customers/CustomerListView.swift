import SwiftUI

struct CustomerListView: View {
    @StateObject private var viewModel: CustomerListViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isAddingCustomer = false
    @State private var isViewingCustomer = false
    @State private var isChoosingAddMode = false
    @State private var isImportingContact = false

    init(viewModel: CustomerListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    customerList
                } detail: {
                    if viewModel.selectedCustomer == nil {
                        ContentUnavailableView(
                            "Select a customer",
                            systemImage: "person.crop.circle",
                            description: Text("Choose a customer to view contact details, preferences, and order history.")
                        )
                        .accessibilityIdentifier("customers.detail.empty")
                    } else {
                        CustomerDetailView(
                            viewModel: viewModel,
                            isPresented: .constant(true),
                            showsDoneButton: false
                        )
                    }
                }
            } else {
                customerList
            }
        }
        .confirmationDialog("Add Customer", isPresented: $isChoosingAddMode) {
            Button("Import From Contacts") {
                isImportingContact = true
            }
            Button("Enter Manually") {
                viewModel.beginAddingCustomer()
                isAddingCustomer = true
            }
            Button("Cancel", role: .cancel) {}
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
        }
        .accessibilityIdentifier(AppDestination.customers.screenAccessibilityIdentifier)
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
                CloudBakeSection("Customers") {
                    VStack(spacing: 16) {
                    ForEach(viewModel.customers, id: \.id) { customer in
                        Button {
                            openCustomer(customer)
                        } label: {
                            HStack(spacing: 18) {
                                CloudBakeRowIcon(systemImage: "person.crop.circle", tint: .cloudBakeTeal)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(customer.name)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(customer.phone)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if let allergies = customer.allergies {
                                        Label(allergies, systemImage: "exclamationmark.triangle")
                                            .font(.footnote)
                                            .foregroundStyle(.orange)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.cloudBakePink.opacity(0.72))
                                    .accessibilityHidden(true)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .cloudBakeCardStyle()
                        .accessibilityIdentifier("customers.item.\(customer.id)")
                    }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                CloudBakeErrorBanner(
                    message: errorMessage,
                    accessibilityIdentifier: "customers.error"
                )
            }
        }
    }

    private func openCustomer(_ customer: Customer) {
        viewModel.beginViewingCustomer(customer)
        if horizontalSizeClass != .regular {
            isViewingCustomer = true
        }
    }
}
