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
                        .navigationTitle("Customers")
                        .toolbar {
                            addCustomerToolbarItem
                        }
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
                    .navigationTitle("Customers")
                    .toolbar {
                        addCustomerToolbarItem
                    }
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
        List {
            if viewModel.customers.isEmpty {
                ContentUnavailableView(
                    "No customers yet",
                    systemImage: "person.2",
                    description: Text("Add customers before linking preferences and allergy notes to orders.")
                )
            } else {
                Section("Customers") {
                    ForEach(viewModel.customers, id: \.id) { customer in
                        Button {
                            openCustomer(customer)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(customer.name)
                                    .font(.headline)
                                Text(customer.phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let allergies = customer.allergies {
                                    Label(allergies, systemImage: "exclamationmark.triangle")
                                        .font(.footnote)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("customers.item.\(customer.id)")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("customers.error")
                }
            }
        }
    }

    private var addCustomerToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isChoosingAddMode = true
            } label: {
                Label("Add Customer", systemImage: "plus")
            }
            .accessibilityIdentifier("customers.add")
        }
    }

    private func openCustomer(_ customer: Customer) {
        viewModel.beginViewingCustomer(customer)
        if horizontalSizeClass != .regular {
            isViewingCustomer = true
        }
    }
}
