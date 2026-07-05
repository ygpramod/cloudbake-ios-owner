import PhotosUI
import SwiftUI
import UIKit

struct RecipeListView: View {
    @StateObject private var viewModel: RecipeListViewModel
    @State private var isAddingRecipe = false
    @State private var isImportingRecipe = false

    init(viewModel: RecipeListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.recipes.isEmpty {
                ContentUnavailableView(
                    "No recipes yet",
                    systemImage: "book",
                    description: Text("Add trusted cake recipes before ingredients and recipe-book conversion arrive.")
                )
            } else {
                Section("Recipes") {
                    ForEach(viewModel.recipes, id: \.id) { recipe in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recipe.name)
                                .font(.headline)
                            if let notes = recipe.notes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("recipes.item.\(recipe.id)")
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isImportingRecipe = true
                } label: {
                    Label("Import recipe", systemImage: "doc.text.viewfinder")
                }
                .accessibilityIdentifier("recipes.import")

                Button {
                    isAddingRecipe = true
                } label: {
                    Label("Add recipe", systemImage: "plus")
                }
                .accessibilityIdentifier("recipes.add")
            }
        }
        .sheet(isPresented: $isAddingRecipe, onDismiss: viewModel.cancelAddRecipe) {
            NavigationStack {
                RecipeForm(
                    viewModel: viewModel,
                    isPresented: $isAddingRecipe
                )
            }
        }
        .sheet(isPresented: $isImportingRecipe, onDismiss: viewModel.cancelRecipeImport) {
            NavigationStack {
                RecipeImportView(
                    viewModel: viewModel,
                    isPresented: $isImportingRecipe
                )
            }
        }
        .onAppear {
            viewModel.load()
        }
        .accessibilityIdentifier(AppDestination.recipes.screenAccessibilityIdentifier)
    }
}

private struct RecipeImportView: View {
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
                    if viewModel.addRecipe() {
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
                    return
                }

                selectedRecipeImage = image
                recognize(image)
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

private struct RecipeForm: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Binding var isPresented: Bool

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
        .navigationTitle("Add Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelAddRecipe()
                    isPresented = false
                }
                .accessibilityIdentifier("recipes.form.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.addRecipe() {
                        isPresented = false
                    }
                }
                .accessibilityIdentifier("recipes.form.save")
            }
        }
    }
}

#Preview {
    NavigationStack {
        if let database = try? AppDatabase.makeInMemory() {
            RecipeListView(
                viewModel: RecipeListViewModel(
                    repository: database.makeCoreDataRepository()
                )
            )
        }
    }
}
