import SwiftUI

struct DesignSelectionView: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.clearDraftCakeDesignLink()
                    isPresented = false
                } label: {
                    HStack {
                        Text("No Linked Design")
                        Spacer()
                        if viewModel.draftCakeDesignId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("orders.designSelection.none")
            }

            Section("Designs") {
                let matchingDesigns = viewModel.cakeDesigns(matching: searchText)
                if matchingDesigns.isEmpty {
                    Text("No matching designs")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orders.designSelection.empty")
                } else {
                    ForEach(matchingDesigns, id: \.id) { design in
                        Button {
                            viewModel.selectDraftCakeDesign(id: design.id)
                            isPresented = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(design.name)
                                        .font(.headline)
                                    if let notes = design.notes {
                                        Text(notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let photoReference = design.photoReference {
                                        Label(photoReference, systemImage: "photo")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if viewModel.draftCakeDesignId == design.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("orders.designSelection.design.\(design.id)")
                    }
                }
            }
        }
        .navigationTitle("Design")
        .searchable(text: $searchText, prompt: "Search Designs")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    isPresented = false
                }
                .accessibilityIdentifier("orders.designSelection.done")
            }
        }
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
