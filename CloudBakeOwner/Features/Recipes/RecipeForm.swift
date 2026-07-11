import SwiftUI

struct RecipeForm: View {
    let title: String
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    let onCancel: () -> Void
    let onSave: () -> Bool

    init(
        title: String = "Add Recipe",
        viewModel: RecipeListViewModel,
        isPresented: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Bool
    ) {
        self.title = title
        self.viewModel = viewModel
        _isPresented = isPresented
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Recipe") {
                TextField("Name", text: $viewModel.draftName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("recipes.form.name")

                TextField("Notes", text: $viewModel.draftNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("recipes.form.notes")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if onSave() {
                        isPresented = false
                    }
                }
                .disabled(!viewModel.canSubmitRecipeDraft)
                .accessibilityIdentifier("recipes.form.save")
            }
        }
    }
}
