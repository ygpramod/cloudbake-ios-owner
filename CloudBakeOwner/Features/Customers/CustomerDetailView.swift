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
        List {
            if let customer = viewModel.selectedCustomer {
                Section("Contact") {
                    LabeledContent("Name", value: customer.name)
                    LabeledContent("Phone", value: customer.phone)
                    if let email = customer.email {
                        LabeledContent("Email", value: email)
                    }
                    if let address = customer.address {
                        LabeledContent("Address", value: address)
                    }
                }

                if !viewModel.selectedCustomerImportantDates.isEmpty {
                    Section("Important Dates") {
                        ForEach(viewModel.selectedCustomerImportantDates, id: \.id) { importantDate in
                            LabeledContent(importantDate.label, value: importantDate.date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }

                Section("Preferences") {
                    if let likes = customer.likes {
                        LabeledContent("Likes", value: likes)
                    }
                    if let dislikes = customer.dislikes {
                        LabeledContent("Dislikes", value: dislikes)
                    }
                    if let allergies = customer.allergies {
                        LabeledContent("Allergies", value: allergies)
                    }
                    if let dietaryRestrictions = customer.dietaryRestrictions {
                        LabeledContent("Dietary Restrictions", value: dietaryRestrictions)
                    }
                    if let notes = customer.notes {
                        LabeledContent("Notes", value: notes)
                    }
                }

                Section("Orders") {
                    if viewModel.selectedCustomerOrders.isEmpty {
                        Text("No linked orders yet")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("customers.detail.noOrders")
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
                            .accessibilityIdentifier("customers.detail.order.\(order.id)")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("customers.detail.error")
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedCustomer?.name ?? "Customer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.beginEditingCustomer()
                    isEditingCustomer = true
                } label: {
                    Label("Edit Customer", systemImage: "pencil")
                }
                .accessibilityIdentifier("customers.detail.edit")
            }

            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .accessibilityIdentifier("customers.detail.done")
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
}
