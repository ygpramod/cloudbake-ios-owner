import SwiftUI

struct CustomerForm: View {
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
