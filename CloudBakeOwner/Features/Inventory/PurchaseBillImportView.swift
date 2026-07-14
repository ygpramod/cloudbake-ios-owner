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
        .cloudBakeFormScreenStyle()
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

            Toggle(
                "Has Expiry Date",
                isOn: Binding(
                    get: { draft.hasExpiryDate },
                    set: { hasExpiryDate in
                        draft.hasExpiryDate = hasExpiryDate
                        draft.expiryUsesDefault = false
                    }
                )
            )
            .accessibilityIdentifier("inventory.purchaseBill.draft.hasExpiryDate.\(draft.id)")

            if draft.hasExpiryDate {
                DatePicker(
                    "Expiry Date",
                    selection: Binding(
                        get: { draft.expiryDate },
                        set: { expiryDate in
                            draft.expiryDate = expiryDate
                            draft.expiryUsesDefault = false
                        }
                    ),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("inventory.purchaseBill.draft.expiry.\(draft.id)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("inventory.purchaseBill.draft.\(draft.id)")
    }
}

struct VoiceInventoryImportView: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @Binding var isPresented: Bool
    @StateObject private var recognitionSession: VoiceInventoryRecognitionSession
    @State private var pendingUnknownDraftId: String?
    @State private var mappingDraftId: String?
    @State private var inventorySearch = ""

    @MainActor
    init(
        viewModel: InventoryListViewModel,
        isPresented: Binding<Bool>
    ) {
        self.init(
            viewModel: viewModel,
            isPresented: isPresented,
            recognizer: OnDeviceVoiceInventorySpeechRecognizer()
        )
    }

    @MainActor
    init(
        viewModel: InventoryListViewModel,
        isPresented: Binding<Bool>,
        recognizer: any VoiceInventorySpeechRecognizing
    ) {
        self.viewModel = viewModel
        _isPresented = isPresented
        _recognitionSession = StateObject(
            wrappedValue: VoiceInventoryRecognitionSession(recognizer: recognizer)
        )
    }

    var body: some View {
        Form {
            Section("Voice Inventory") {
                Text("Recognition stays on this iPhone and uses the current iPhone language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $viewModel.voiceInventoryTranscript)
                    .frame(minHeight: 110)
                    .accessibilityLabel("Recognized inventory")
                    .accessibilityIdentifier("inventory.voice.transcript")

                Button {
                    recognitionSession.isListening ? stopListening() : startListening()
                } label: {
                    Label(
                        listeningButtonTitle,
                        systemImage: recognitionSession.isListening ? "stop.fill" : "mic.fill"
                    )
                }
                .disabled(recognitionSession.isRequestingPermission)
                .accessibilityIdentifier("inventory.voice.listen")

                Button {
                    stopListening()
                    if viewModel.createVoiceInventoryDrafts() {
                        offerNextUnknownDraft()
                    }
                } label: {
                    Label("Create Drafts", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.voiceInventoryTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("inventory.voice.createDrafts")
            }

            if !viewModel.voiceInventoryDrafts.isEmpty {
                Section("Draft Items") {
                    ForEach($viewModel.voiceInventoryDrafts) { $draft in
                        VoiceInventoryDraftRow(
                            draft: $draft,
                            destinationName: destinationName(for: draft.destination),
                            onNameChange: { name in
                                viewModel.updateVoiceInventoryDraftName(draft.id, name: name)
                            },
                            onResolve: {
                                pendingUnknownDraftId = draft.id
                            }
                        )
                    }
                }
            }

            if let message = recognitionSession.errorMessage ?? viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("inventory.voice.error")
                }
            }
        }
        .cloudBakeFormScreenStyle()
        .navigationTitle("Add by Voice")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    stopListening()
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    stopListening()
                    if viewModel.saveVoiceInventoryDrafts() {
                        isPresented = false
                    }
                }
                .disabled(!viewModel.canSaveVoiceInventoryDrafts)
                .accessibilityIdentifier("inventory.voice.save")
            }
        }
        .onDisappear(perform: stopListening)
        .sheet(isPresented: mappingSheetPresented) {
            NavigationStack {
                List(filteredInventoryItems, id: \.id) { item in
                    Button {
                        if let mappingDraftId {
                            viewModel.mapVoiceInventoryDraft(mappingDraftId, to: item.id)
                        }
                        self.mappingDraftId = nil
                        inventorySearch = ""
                        offerNextUnknownDraft()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text("\(item.currentQuantity.formatted()) \(item.unit.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("inventory.voice.map.item.\(item.id)")
                }
                .navigationTitle("Map Inventory")
                .searchable(text: $inventorySearch, prompt: "Search inventory")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            mappingDraftId = nil
                            inventorySearch = ""
                        }
                    }
                }
            }
        }
        .cloudBakeCenteredPopup(
            isPresented: pendingUnknownDraftId != nil,
            title: "Inventory Item Not Found",
            subtitle: unknownDraftSubtitle,
            systemImage: "questionmark.circle",
            cancelAccessibilityIdentifier: "inventory.voice.unknown.cancel",
            onCancel: { pendingUnknownDraftId = nil }
        ) {
            centeredPopupButton("Map to Existing Inventory") {
                let draftId = pendingUnknownDraftId
                pendingUnknownDraftId = nil
                DispatchQueue.main.async {
                    mappingDraftId = draftId
                }
            }
            .accessibilityIdentifier("inventory.voice.unknown.map")

            centeredPopupButton("Create as New Inventory") {
                if let pendingUnknownDraftId {
                    viewModel.resolveVoiceInventoryDraftAsNew(pendingUnknownDraftId)
                }
                self.pendingUnknownDraftId = nil
                offerNextUnknownDraft()
            }
            .accessibilityIdentifier("inventory.voice.unknown.create")
        }
    }

    private var mappingSheetPresented: Binding<Bool> {
        Binding(
            get: { mappingDraftId != nil },
            set: { isPresented in
                if !isPresented {
                    mappingDraftId = nil
                }
            }
        )
    }

    private var filteredInventoryItems: [InventoryItem] {
        let query = TextInputFormatting.normalizedSearchKey(inventorySearch)
        let compatibleItems: [InventoryItem]
        if let mappingDraftId,
           let draft = viewModel.voiceInventoryDrafts.first(where: { $0.id == mappingDraftId }) {
            compatibleItems = viewModel.items.filter {
                draft.unit.convertedQuantity(1, to: $0.unit) != nil
            }
        } else {
            compatibleItems = viewModel.items
        }
        guard !query.isEmpty else {
            return compatibleItems
        }
        return compatibleItems.filter {
            TextInputFormatting.normalizedSearchKey($0.name).contains(query)
                || $0.aliases.contains { TextInputFormatting.normalizedSearchKey($0).contains(query) }
        }
    }

    private var unknownDraftSubtitle: String {
        guard let id = pendingUnknownDraftId,
              let draft = viewModel.voiceInventoryDrafts.first(where: { $0.id == id }) else {
            return "Choose how this spoken item should be saved."
        }
        return "\(draft.name) is not in inventory. Map it to an existing item or create it as new inventory."
    }

    private func destinationName(for destination: VoiceInventoryDraftDestination) -> String {
        switch destination {
        case .unresolved: "Needs a decision"
        case .newItem: "Creates new inventory"
        case .existingItem(let id):
            "Adds to \(viewModel.items.first(where: { $0.id == id })?.name ?? "existing inventory")"
        }
    }

    private func offerNextUnknownDraft() {
        pendingUnknownDraftId = viewModel.voiceInventoryDrafts.first {
            $0.destination == .unresolved
        }?.id
    }

    private func startListening() {
        recognitionSession.start { transcript in
            viewModel.voiceInventoryTranscript = transcript
        }
    }

    private func stopListening() {
        recognitionSession.stop()
    }

    private var listeningButtonTitle: String {
        if recognitionSession.isRequestingPermission {
            return "Requesting Access"
        }
        return recognitionSession.isListening ? "Stop Listening" : "Start Listening"
    }
}

private struct VoiceInventoryDraftRow: View {
    @Binding var draft: VoiceInventoryDraft
    let destinationName: String
    let onNameChange: (String) -> Void
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.sourcePhrase)
                .font(.caption)
                .foregroundStyle(.secondary)
            Label(destinationName, systemImage: "arrow.triangle.branch")
                .font(.caption)
                .foregroundStyle(.blue)
            if draft.destination == .unresolved {
                Button("Choose Where to Save", action: onResolve)
                    .accessibilityIdentifier("inventory.voice.draft.resolve.\(draft.id)")
            }

            TextField(
                "Name",
                text: Binding(
                    get: { draft.name },
                    set: onNameChange
                )
            )
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("inventory.voice.draft.name.\(draft.id)")

            HStack {
                TextField("Quantity", text: $draft.quantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.voice.draft.quantity.\(draft.id)")
                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.inventoryInputCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            }

            TextField("Minimum Quantity", text: $draft.minimumQuantityText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("inventory.voice.draft.minimum.\(draft.id)")

            Toggle("Has Expiry Date", isOn: Binding(
                get: { draft.hasExpiryDate },
                set: {
                    draft.hasExpiryDate = $0
                    draft.expiryUsesDefault = false
                }
            ))
            if draft.hasExpiryDate {
                DatePicker(
                    "Expiry Date",
                    selection: Binding(
                        get: { draft.expiryDate },
                        set: {
                            draft.expiryDate = $0
                            draft.expiryUsesDefault = false
                        }
                    ),
                    displayedComponents: .date
                )
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("inventory.voice.draft.\(draft.id)")
    }
}
