import SwiftUI

struct DesignSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedTag: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            CloudBakeScreenBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CloudBakeSearchField(
                        text: $searchText,
                        prompt: "Search designs",
                        accessibilityIdentifier: "orders.designSelection.search",
                        isFocused: $isSearchFocused
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterButton("All", tag: nil)
                            ForEach(viewModel.mostUsedDesignTags, id: \.self) { tag in
                                filterButton("#\(tag)", tag: tag)
                            }
                        }
                    }
                    .accessibilityIdentifier("orders.designSelection.filters")

                    if !viewModel.draftCustomerReferencePhotoId.isEmpty {
                        Label("Customer Reference is linked", systemImage: "person.crop.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.cloudBakePink)
                            .accessibilityIdentifier("orders.designSelection.customerReference")
                    }

                    if matchingDesigns.isEmpty && matchingCustomerReferences.isEmpty {
                        CloudBakeEmptyState(
                            title: "No matching designs",
                            systemImage: "photo.on.rectangle.angled",
                            message: "Try another name or tag."
                        )
                        .accessibilityIdentifier("orders.designSelection.empty")
                    }

                    Text("My Designs (\(matchingDesigns.count))")
                        .font(CloudBakeTheme.Typography.sectionTitle)
                        .accessibilityIdentifier("orders.designSelection.myDesigns.title")

                    if !matchingDesigns.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(matchingDesigns, id: \.id) { design in
                                designTile(design)
                            }
                        }
                    }

                    Text("Customer References (\(matchingCustomerReferences.count))")
                        .font(CloudBakeTheme.Typography.sectionTitle)
                        .accessibilityIdentifier("orders.designSelection.customerReferences.title")

                    if !matchingCustomerReferences.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(matchingCustomerReferences) { reference in
                                customerReferenceTile(reference)
                            }
                        }
                    }
                }
                .padding(CloudBakeTheme.Spacing.screenHorizontal)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Choose Design")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Clear Link") {
                    viewModel.clearDraftCakeDesignLink()
                    isPresented = false
                }
                .disabled(
                    viewModel.draftCakeDesignId.isEmpty
                        && viewModel.draftCustomerReferencePhotoId.isEmpty
                )
                .accessibilityIdentifier("orders.designSelection.none")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.designSelection.done")
            }
        }
    }

    private var matchingDesigns: [CakeDesign] {
        viewModel.cakeDesigns(matching: searchText, tag: selectedTag)
    }

    private var matchingCustomerReferences: [CustomerReferenceDesign] {
        viewModel.customerReferences(matching: searchText, tag: selectedTag)
    }

    private func filterButton(_ title: String, tag: String?) -> some View {
        Button(title) { selectedTag = tag }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(selectedTag == tag ? Color.cloudBakePink : Color.secondary)
            .accessibilityAddTraits(selectedTag == tag ? .isSelected : [])
    }

    private func designTile(_ design: CakeDesign) -> some View {
        Button {
            viewModel.selectDraftCakeDesign(id: design.id)
            isPresented = false
        } label: {
            ZStack(alignment: .topTrailing) {
                DesignPhotoView(
                    source: viewModel.designPhotoSource(for: design),
                    maximumPixelSize: 600,
                    contentMode: .fill
                )
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if viewModel.draftCakeDesignId == design.id {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.cloudBakePink, in: Capsule())
                        .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        viewModel.draftCakeDesignId == design.id
                            ? Color.cloudBakePink
                            : Color.clear,
                        lineWidth: 3
                    )
            }
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityLabel("\(design.name), design")
        .accessibilityAddTraits(
            viewModel.draftCakeDesignId == design.id ? .isSelected : []
        )
        .accessibilityIdentifier("orders.designSelection.design.\(design.id)")
    }

    private func customerReferenceTile(_ reference: CustomerReferenceDesign) -> some View {
        Button {
            viewModel.selectDraftCustomerReference(photoId: reference.photo.id)
            isPresented = false
        } label: {
            ZStack(alignment: .topTrailing) {
                DesignPhotoView(
                    source: viewModel.designPhotoSource(for: reference),
                    maximumPixelSize: 600,
                    contentMode: .fill
                )
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if viewModel.draftCustomerReferencePhotoId == reference.photo.id {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.cloudBakePink, in: Capsule())
                        .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        viewModel.draftCustomerReferencePhotoId == reference.photo.id
                            ? Color.cloudBakePink
                            : Color.clear,
                        lineWidth: 3
                    )
            }
        }
        .buttonStyle(.plain)
        .cloudBakeCardStyle()
        .accessibilityLabel(
            "\(reference.title), customer reference from \(reference.order.customerName)"
        )
        .accessibilityAddTraits(
            viewModel.draftCustomerReferencePhotoId == reference.photo.id ? .isSelected : []
        )
        .accessibilityIdentifier(
            "orders.designSelection.customerReference.\(reference.photo.id)"
        )
    }
}

struct RecipeSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.clearDraftRecipeLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Recipe")
                        Spacer()
                        if viewModel.draftRecipeId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.recipeSelection.none")
            }

            Section("Recipes") {
                let matchingRecipes = viewModel.recipes(matching: searchText)
                if matchingRecipes.isEmpty {
                    Text("No matching recipes")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.recipeSelection.empty")
                } else {
                    ForEach(matchingRecipes, id: \.id) { recipe in
                        Button {
                            viewModel.selectDraftRecipe(id: recipe.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name)
                                        .font(.headline)
                                    if let notes = recipe.notes {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if viewModel.draftRecipeId == recipe.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.recipeSelection.recipe.\(recipe.id)")
                    }
                }
            }
        }
        .navigationTitle("Recipe")
        .searchable(text: $searchText, prompt: "Search Recipes")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.recipeSelection.done")
            }
        }
    }
}

struct CustomerSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @StateObject private var customerViewModel: CustomerListViewModel
    @State private var searchText = ""
    @State private var isAddingCustomer = false
    @State private var isChoosingAddMode = false
    @State private var isImportingContact = false

    init(viewModel: OrderListViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        _isPresented = isPresented
        _customerViewModel = StateObject(wrappedValue: viewModel.makeCustomerListViewModel())
    }

    var body: some View {
        List {
            Section {
                Button {
                    isChoosingAddMode = true
                } label: {
                    Label("New Customer", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("orders.customerSelection.newCustomer")

                Button {
                    viewModel.clearDraftCustomerLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Customer")
                        Spacer()
                        if viewModel.draftCustomerId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.customerSelection.none")
            }

            Section("Customers") {
                let matchingCustomers = viewModel.customers(matching: searchText)
                if matchingCustomers.isEmpty {
                    Text("No matching customers")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.customerSelection.empty")
                } else {
                    ForEach(matchingCustomers, id: \.id) { customer in
                        Button {
                            viewModel.selectDraftCustomer(id: customer.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(customer.name)
                                        .font(.headline)
                                    Text(customer.phone)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    if let allergies = customer.allergies {
                                        Label(allergies, systemImage: "exclamationmark.triangle")
                                            .font(.footnote)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                if viewModel.draftCustomerId == customer.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.customerSelection.customer.\(customer.id)")
                    }
                }
            }
        }
        .navigationTitle("Customer Record")
        .searchable(text: $searchText, prompt: "Search Customers")
        .cloudBakeCenteredPopup(
            isPresented: isChoosingAddMode,
            title: "Add Customer",
            subtitle: "Choose how to start this customer record",
            systemImage: "person.badge.plus",
            cancelAccessibilityIdentifier: "orders.customerSelection.add.cancel",
            onCancel: { isChoosingAddMode = false }
        ) {
            centeredPopupButton("Import From Contacts") {
                isChoosingAddMode = false
                isImportingContact = true
            }
            .accessibilityIdentifier("orders.customerSelection.add.importContacts")

            centeredPopupButton("Enter Manually") {
                isChoosingAddMode = false
                customerViewModel.beginAddingCustomer()
                isAddingCustomer = true
            }
            .accessibilityIdentifier("orders.customerSelection.add.manual")
        }
        .sheet(isPresented: $isImportingContact) {
            CustomerContactPicker { contact in
                let draft = CustomerContactDraftMapper().draft(from: contact)
                customerViewModel.beginAddingCustomer(importedDraft: draft)
                isImportingContact = false
                DispatchQueue.main.async {
                    isAddingCustomer = true
                }
            }
        }
        .sheet(isPresented: $isAddingCustomer) {
            NavigationStack {
                CustomerForm(
                    viewModel: customerViewModel,
                    isPresented: $isAddingCustomer,
                    onCancel: customerViewModel.cancelAddCustomer,
                    onSave: saveCustomerAndSelect
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.customerSelection.done")
            }
        }
    }

    private func saveCustomerAndSelect() -> Bool {
        guard customerViewModel.addCustomer(),
              let customer = customerViewModel.lastSavedCustomer else {
            return false
        }

        viewModel.reloadCustomers()
        viewModel.selectDraftCustomer(id: customer.id)
        isPresented = false
        return true
    }
}
