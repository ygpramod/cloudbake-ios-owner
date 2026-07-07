import PhotosUI
import SwiftUI
import UIKit

struct RecipeImportView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool
    @State private var isShowingCamera = false
    @State private var selectedRecipeImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let recognizer: RecipeTextRecognizing

    init(
        viewModel: RecipeListViewModel,
        isPresented: Binding<Bool>,
        recognizer: RecipeTextRecognizing = VisionRecipeTextRecognizer()
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.recognizer = recognizer
    }

    var body: some View {
        Form {
            Section("Recipe Photo") {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(selectedRecipeImage == nil ? "Take Recipe Photo" : "Retake Recipe Photo", systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.camera")

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose From Library", systemImage: "photo.on.rectangle")
                }
                .disabled(viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.library")

                if let selectedRecipeImage {
                    Image(uiImage: selectedRecipeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("recipes.import.preview")
                }

                if viewModel.isRecognizingRecipeScan {
                    ProgressView("Reading recipe")
                        .accessibilityIdentifier("recipes.import.recognizing")
                }
            }

            Section("Recipe Text") {
                TextField("Recipe Text", text: $viewModel.recipeScanRecognizedText, axis: .vertical)
                    .lineLimit(4...10)
                    .accessibilityIdentifier("recipes.import.text")

                Button {
                    _ = viewModel.createRecipeDraftFromRecognizedText()
                } label: {
                    Label("Create Draft", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isRecognizingRecipeScan)
                .accessibilityIdentifier("recipes.import.createDraft")
            }

            Section("Draft Recipe") {
                TextField("Name", text: $viewModel.draftName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("recipes.import.name")

                TextField("Notes", text: $viewModel.draftNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("recipes.import.notes")
            }

            if !viewModel.importIngredientDrafts.isEmpty {
                Section("Draft Ingredients") {
                    ForEach($viewModel.importIngredientDrafts) { $draft in
                        RecipeImportIngredientDraftRowView(
                            draft: $draft,
                            inventoryItems: viewModel.availableInventoryItems
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("recipes.import.error")
                }
            }
        }
        .navigationTitle("Import Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelRecipeImport()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.import.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.saveRecipeImportDraft() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("recipes.import.save")
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            RecipeCameraView { image in
                selectedRecipeImage = image
                recognize(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else {
                return
            }

            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    viewModel.errorMessage = "Recipe image could not be opened."
                    selectedPhotoItem = nil
                    return
                }

                selectedRecipeImage = image
                recognize(image)
                selectedPhotoItem = nil
            }
        }
    }

    private func recognize(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            viewModel.errorMessage = "Recipe image could not be opened."
            return
        }

        Task {
            _ = await viewModel.recognizeRecipeImage(
                cgImage,
                recognizer: recognizer
            )
        }
    }
}

private struct RecipeImportIngredientDraftRowView: View {
    @Binding var draft: RecipeImportIngredientDraftRow
    let inventoryItems: [InventoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ingredient", text: $draft.name)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("recipes.import.ingredient.name.\(draft.id)")

            Picker("Inventory Item", selection: $draft.inventoryItemId) {
                Text("Choose").tag("")
                ForEach(inventoryItems, id: \.id) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .accessibilityIdentifier("recipes.import.ingredient.inventory.\(draft.id)")

            HStack {
                TextField("Quantity", text: $draft.quantity)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("recipes.import.ingredient.quantity.\(draft.id)")

                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("recipes.import.ingredient.unit.\(draft.id)")
            }

            TextField("Note", text: $draft.note, axis: .vertical)
                .lineLimit(1...3)
                .accessibilityIdentifier("recipes.import.ingredient.note.\(draft.id)")
        }
        .padding(.vertical, 4)
    }
}

private struct RecipeCameraView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImageSelected: onImageSelected,
            dismiss: dismiss
        )
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImageSelected: (UIImage) -> Void
        private let dismiss: DismissAction

        init(
            onImageSelected: @escaping (UIImage) -> Void,
            dismiss: DismissAction
        ) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
