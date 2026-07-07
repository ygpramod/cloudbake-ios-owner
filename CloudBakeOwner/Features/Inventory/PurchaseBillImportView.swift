import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct PurchaseBillImportView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCamera = false
    @State private var hasOfferedCamera = false
    @State private var selectedBillImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let recognizer: PurchaseBillTextRecognizing
    private let catalogProvider: () -> [BakingCatalogItem]

    init(
        viewModel: InventoryListViewModel,
        isPresented: Binding<Bool>,
        recognizer: PurchaseBillTextRecognizing = VisionPurchaseBillTextRecognizer(),
        catalogProvider: @escaping () -> [BakingCatalogItem] = { (try? BakingCatalog.loadBundledCatalog()) ?? [] }
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        self.recognizer = recognizer
        self.catalogProvider = catalogProvider
    }

    var body: some View {
        Form {
            Section("Bill Photo") {
                Button {
                    isShowingCamera = true
                } label: {
                    Label(selectedBillImage == nil ? "Take Bill Photo" : "Retake Bill Photo", systemImage: "camera")
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || viewModel.isRecognizingPurchaseBill)
                .accessibilityIdentifier("inventory.purchaseBill.camera")

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose From Library", systemImage: "photo.on.rectangle")
                }
                .disabled(viewModel.isRecognizingPurchaseBill)
                .accessibilityIdentifier("inventory.purchaseBill.library")

                if let selectedBillImage {
                    Image(uiImage: selectedBillImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("inventory.purchaseBill.preview")
                }

                if viewModel.isRecognizingPurchaseBill {
                    ProgressView("Reading bill")
                        .accessibilityIdentifier("inventory.purchaseBill.recognizing")
                }
            }

            Section("Bill Text") {
                TextField("Bill Text", text: $viewModel.purchaseBillRecognizedText, axis: .vertical)
                    .lineLimit(4...8)
                    .accessibilityIdentifier("inventory.purchaseBill.text")

                Button {
                    _ = viewModel.createPurchaseBillDrafts(catalog: catalogProvider())
                } label: {
                    Label("Create Drafts", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isRecognizingPurchaseBill)
                .accessibilityIdentifier("inventory.purchaseBill.createDrafts")
            }

            if !viewModel.purchaseBillDrafts.isEmpty {
                Section("Draft Items") {
                    ForEach($viewModel.purchaseBillDrafts) { $draft in
                        PurchaseBillDraftRow(
                            draft: $draft,
                            onNameChanged: {
                                viewModel.refreshPurchaseBillDraftMatch(draftId: draft.id)
                            }
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.purchaseBill.error")
                }
            }
        }
        .navigationTitle("Import Bill")
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else {
                return
            }

            Task {
                await importBillPhoto(newItem)
                selectedPhotoItem = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelPurchaseBillImport()
                    isPresented = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.savePurchaseBillDrafts() {
                        isPresented = false
                        dismiss()
                    }
                }
                .disabled(viewModel.purchaseBillDrafts.isEmpty)
                .accessibilityIdentifier("inventory.purchaseBill.save")
            }
        }
        .onAppear {
            guard UIImagePickerController.isSourceTypeAvailable(.camera), !hasOfferedCamera else {
                return
            }
            hasOfferedCamera = true
            isShowingCamera = true
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePickerView { image in
                selectedBillImage = image
                recognizeBillPhoto(image)
            }
            .ignoresSafeArea()
        }
    }

    private func importBillPhoto(_ item: PhotosPickerItem) async {
        do {
            let image = try await PhotoPickerImageLoader.image(from: item)
            selectedBillImage = image
            recognizeBillPhoto(image)
        } catch {
            viewModel.errorMessage = "The bill photo could not be read. Try another photo or enter the bill text manually."
        }
    }

    private func recognizeBillPhoto(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            viewModel.errorMessage = "The bill photo could not be read. Try another photo or enter the bill text manually."
            return
        }

        Task {
            _ = await viewModel.recognizePurchaseBillImage(
                cgImage,
                recognizer: recognizer,
                catalog: catalogProvider()
            )
        }
    }
}

private struct PurchaseBillDraftRow: View {
    @Binding var draft: PurchaseBillInventoryDraft
    let onNameChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $draft.isSelected) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.sourceLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let matchedInventoryItemName = draft.matchedInventoryItemName {
                        Label("Adds To Existing: \(matchedInventoryItemName)", systemImage: "arrow.triangle.merge")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .accessibilityIdentifier("inventory.purchaseBill.draft.selected.\(draft.id)")

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: draft.name) {
                        onNameChanged()
                    }
                    .accessibilityIdentifier("inventory.purchaseBill.draft.name.\(draft.id)")
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Current Quantity", text: $draft.quantityText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("inventory.purchaseBill.draft.quantity.\(draft.id)")
                }

                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .accessibilityIdentifier("inventory.purchaseBill.draft.unit.\(draft.id)")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Minimum Quantity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Minimum Quantity", text: $draft.minimumQuantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.purchaseBill.draft.minimum.\(draft.id)")
            }

            DatePicker(
                "Expiry Date",
                selection: $draft.expiryDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("inventory.purchaseBill.draft.expiry.\(draft.id)")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("inventory.purchaseBill.draft.\(draft.id)")
    }
}
