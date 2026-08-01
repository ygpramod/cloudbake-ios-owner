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
    @State private var pendingCropImage: UIImage?
    @State private var isShowingCrop = false

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
            Section {
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
            } header: {
                InventoryImportSectionHeader(title: "Bill Photo")
            }

            Section {
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
            } header: {
                InventoryImportSectionHeader(title: "Bill Text")
            }

            if !viewModel.purchaseBillDrafts.isEmpty {
                Section {
                    ForEach($viewModel.purchaseBillDrafts) { $draft in
                        PurchaseBillDraftRow(
                            draft: $draft,
                            onNameChanged: {
                                viewModel.refreshPurchaseBillDraftMatch(draftId: draft.id)
                            }
                        )
                    }
                } header: {
                    InventoryImportSectionHeader(title: "Draft Items")
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
        .safeAreaInset(edge: .top, spacing: 0) {
            InventoryImportScreenHeader(
                title: "Import Bill",
                accessibilityIdentifier: "inventory.purchaseBill.screenTitle"
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                pendingCropImage = image
            }
            .ignoresSafeArea()
        }
        .onChange(of: isShowingCamera) { _, isShowing in
            if !isShowing, pendingCropImage != nil {
                isShowingCrop = true
            }
        }
        .fullScreenCover(isPresented: $isShowingCrop) {
            if let pendingCropImage {
                BillImageCropView(
                    image: pendingCropImage,
                    onCancel: cancelCrop,
                    onUseCrop: useCroppedBillImage
                )
            }
        }
    }

    private func importBillPhoto(_ item: PhotosPickerItem) async {
        do {
            let image = try await PhotoPickerImageLoader.image(from: item)
            pendingCropImage = image
            isShowingCrop = true
        } catch {
            viewModel.errorMessage = "The bill photo could not be read. Try another photo or enter the bill text manually."
        }
    }

    private func cancelCrop() {
        isShowingCrop = false
        pendingCropImage = nil
    }

    private func useCroppedBillImage(_ image: UIImage) {
        selectedBillImage = image
        isShowingCrop = false
        pendingCropImage = nil
        recognizeBillPhoto(image)
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
    @State private var isShowingVoiceGuidance = false

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
            Section {
                Button {
                    isShowingVoiceGuidance.toggle()
                } label: {
                    HStack {
                        Label("What should I say?", systemImage: "info.circle")

                        Spacer()

                        Image(systemName: isShowingVoiceGuidance ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel(
                    isShowingVoiceGuidance ? "Hide voice inventory guidance" : "Show voice inventory guidance"
                )
                .accessibilityIdentifier("inventory.voice.guidance.toggle")

                if isShowingVoiceGuidance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Say one item at a time using its name, quantity, and unit.")

                        Text("For example: Flour 800 grams, Strawberries 100 grams, or Eggs 12 pieces.")

                        Text("Pause between items to start a new line. You can edit the transcript before creating drafts.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("inventory.voice.guidance")
                }

                Text("Recognition stays on this iPhone and uses the current iPhone language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: voiceTranscriptBinding)
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
            } header: {
                InventoryImportSectionHeader(title: "Voice Inventory")
            }

            if !viewModel.voiceInventoryDrafts.isEmpty {
                Section {
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
                } header: {
                    InventoryImportSectionHeader(title: "Draft Items")
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
        .safeAreaInset(edge: .top, spacing: 0) {
            InventoryImportScreenHeader(
                title: "Add by Voice",
                accessibilityIdentifier: "inventory.voice.screenTitle"
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
        .cloudBakeConfirmationDialog(
            isPresented: optionalPresentationBinding($pendingUnknownDraftId),
            title: "Inventory Item Not Found",
            message: unknownDraftSubtitle,
            cancelAccessibilityIdentifier: "inventory.voice.unknown.cancel",
            onCancel: { pendingUnknownDraftId = nil }
        ) {
            nativeDialogButton("Map to Existing Inventory") {
                let draftId = pendingUnknownDraftId
                pendingUnknownDraftId = nil
                DispatchQueue.main.async {
                    mappingDraftId = draftId
                }
            }
            .accessibilityIdentifier("inventory.voice.unknown.map")

            nativeDialogButton("Create as New Inventory") {
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
            let draft = viewModel.voiceInventoryDrafts.first(where: { $0.id == mappingDraftId })
        {
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
            let draft = viewModel.voiceInventoryDrafts.first(where: { $0.id == id })
        else {
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
        pendingUnknownDraftId =
            viewModel.voiceInventoryDrafts.first {
                $0.destination == .unresolved
            }?.id
    }

    private func startListening() {
        recognitionSession.start(baselineTranscript: viewModel.voiceInventoryTranscript) { transcript in
            viewModel.voiceInventoryTranscript = transcript
        }
    }

    private var voiceTranscriptBinding: Binding<String> {
        Binding(
            get: { viewModel.voiceInventoryTranscript },
            set: { transcript in
                viewModel.voiceInventoryTranscript = transcript
                recognitionSession.rebaseTranscript(to: transcript)
            }
        )
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

private struct InventoryImportScreenHeader: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack {
            Text(title)
                .font(CloudBakeTheme.Typography.screenTitle)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(accessibilityIdentifier)

            Spacer()
        }
        .padding(.horizontal, CloudBakeTheme.Spacing.screenHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(CloudBakeScreenBackground())
    }
}

private struct InventoryImportSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(CloudBakeTheme.Typography.sectionTitle)
            .foregroundStyle(.primary)
            .textCase(nil)
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

            if draft.showsMinimumQuantity {
                TextField("Minimum Quantity", text: $draft.minimumQuantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("inventory.voice.draft.minimum.\(draft.id)")
            }

            Toggle(
                "Has Expiry Date",
                isOn: Binding(
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
