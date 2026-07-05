import Contacts
import ContactsUI
import SwiftUI

struct CustomerListView: View {
    @StateObject private var viewModel: CustomerListViewModel
    @State private var isAddingCustomer = false
    @State private var isViewingCustomer = false
    @State private var isChoosingAddMode = false
    @State private var isImportingContact = false

    init(viewModel: CustomerListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
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
                            viewModel.beginViewingCustomer(customer)
                            isViewingCustomer = true
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
        .navigationTitle("Customers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isChoosingAddMode = true
                } label: {
                    Label("Add Customer", systemImage: "plus")
                }
                .accessibilityIdentifier("customers.add")
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
}

private struct CustomerContactPicker: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactPostalAddressesKey,
            CNContactBirthdayKey,
            CNContactDatesKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactSelected: onContactSelected)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onContactSelected: (CNContact) -> Void

        init(onContactSelected: @escaping (CNContact) -> Void) {
            self.onContactSelected = onContactSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactSelected(contact)
        }
    }
}

private struct CustomerDetailView: View {
    @ObservedObject var viewModel: CustomerListViewModel
    @Binding var isPresented: Bool
    @State private var isEditingCustomer = false

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

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("customers.detail.done")
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

private struct CustomerForm: View {
    let title: String
    @ObservedObject var viewModel: CustomerListViewModel
    @Binding var isPresented: Bool
    let showsImportantDate: Bool
    let onCancel: () -> Void
    let onSave: () -> Bool

    init(
        title: String = "Add Customer",
        viewModel: CustomerListViewModel,
        isPresented: Binding<Bool>,
        showsImportantDate: Bool = true,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Bool
    ) {
        self.title = title
        self.viewModel = viewModel
        _isPresented = isPresented
        self.showsImportantDate = showsImportantDate
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Name", text: $viewModel.draftName)
                    .textContentType(.name)
                    .accessibilityIdentifier("customers.form.name")

                TextField("Phone", text: $viewModel.draftPhone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .accessibilityIdentifier("customers.form.phone")

                TextField("Email", text: $viewModel.draftEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("customers.form.email")

                TextField("Address", text: $viewModel.draftAddress, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("customers.form.address")
            }

            if let duplicateWarningMessage = viewModel.duplicateWarningMessage {
                Section {
                    Text(duplicateWarningMessage)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("customers.form.duplicateWarning")
                }
            }

            if showsImportantDate {
                Section("Important Date") {
                    TextField("Label", text: $viewModel.draftImportantDateLabel)
                        .accessibilityIdentifier("customers.form.importantDate.label")

                    DatePicker(
                        "Date",
                        selection: $viewModel.draftImportantDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("customers.form.importantDate.date")
                }
            }

            Section("Preferences") {
                TextField("Likes", text: $viewModel.draftLikes, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("customers.form.likes")

                TextField("Dislikes", text: $viewModel.draftDislikes, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("customers.form.dislikes")

                TextField("Allergies", text: $viewModel.draftAllergies, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("customers.form.allergies")

                TextField("Dietary Restrictions", text: $viewModel.draftDietaryRestrictions, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityIdentifier("customers.form.dietaryRestrictions")

                TextField("Notes", text: $viewModel.draftNotes, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("customers.form.notes")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("customers.form.error")
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    isPresented = false
                }
                .accessibilityIdentifier("customers.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("customers.form.save")
            }
        }
    }
}
