import SwiftUI

struct OrderCakeSpecificationSection: View {
    @ObservedObject var viewModel: OrderListViewModel
    @State private var basicsAreExpanded = false
    @State private var flavoursAreExpanded = false
    @State private var decorationIsExpanded = false

    var body: some View {
        Section("Cake Requirements") {
            if let summary = viewModel.draftCakeSpecificationSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("orders.form.cakeSpecification.summary")
            }

            DisclosureGroup(isExpanded: $basicsAreExpanded) {
                choiceRow(
                    "Occasion",
                    field: .occasion,
                    value: $viewModel.draftCakeOccasion,
                    defaults: ["Birthday", "Wedding", "Anniversary", "Baby Shower", "Celebration"]
                )

                TextField("Servings", text: $viewModel.draftCakeServings)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("orders.form.cakeSpecification.servings")

                if viewModel.draftCakeServings.isEmpty,
                    let weight = Decimal(string: viewModel.draftCakeWeightKilograms),
                    let suggestion = OrderCakeSpecification.suggestedServings(forWeightKilograms: weight)
                {
                    suggestionButton("Use suggested servings: \(suggestion)") {
                        viewModel.applySuggestedCakeServings()
                    }
                }

                TextField("Weight (kg)", text: $viewModel.draftCakeWeightKilograms)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("orders.form.cakeSpecification.weight")

                if viewModel.draftCakeWeightKilograms.isEmpty,
                    let servings = Int(viewModel.draftCakeServings),
                    let suggestion = OrderCakeSpecification.suggestedWeight(forServings: servings)
                {
                    suggestionButton(
                        "Use suggested weight: \(NSDecimalNumber(decimal: suggestion).stringValue) kg"
                    ) {
                        viewModel.applySuggestedCakeWeight()
                    }
                }

                choiceRow(
                    "Size",
                    field: .size,
                    value: $viewModel.draftCakeSize,
                    defaults: ["4 in", "6 in", "8 in", "10 in", "12 in"]
                )
                choiceRow(
                    "Shape",
                    field: .shape,
                    value: $viewModel.draftCakeShape,
                    defaults: ["Circle", "Square", "Oval"]
                )
                choiceRow(
                    "Tiers",
                    field: .tiers,
                    value: $viewModel.draftCakeTiers,
                    defaults: ["1", "2", "3"]
                )
            } label: {
                Text("Size And Shape")
                    .accessibilityIdentifier("orders.form.cakeSpecification.sizeAndShape.disclosure")
            }

            DisclosureGroup("Flavours And Finish", isExpanded: $flavoursAreExpanded) {
                choiceRow(
                    "Sponge",
                    field: .spongeFlavour,
                    value: $viewModel.draftCakeSpongeFlavour,
                    defaults: ["Vanilla", "Chocolate"]
                )
                choiceRow(
                    "Filling",
                    field: .filling,
                    value: $viewModel.draftCakeFilling,
                    defaults: ["Buttercream", "Chocolate Ganache", "Fruit"]
                )
                choiceRow(
                    "Frosting",
                    field: .frosting,
                    value: $viewModel.draftCakeFrosting,
                    defaults: ["Buttercream", "Whipped Cream", "Ganache", "Fondant"]
                )
            }

            DisclosureGroup("Decoration And Packaging", isExpanded: $decorationIsExpanded) {
                suggestionTextField(
                    "Colour Palette",
                    field: .colourPalette,
                    text: $viewModel.draftCakeColourPalette
                )
                suggestionTextField(
                    "Theme",
                    field: .theme,
                    text: $viewModel.draftCakeTheme
                )
                choiceRow(
                    "Topper",
                    field: .topperRequirements,
                    value: $viewModel.draftCakeTopperRequirements,
                    defaults: ["None"]
                )
                choiceRow(
                    "Candles And Accessories",
                    field: .candlesAndAccessories,
                    value: $viewModel.draftCakeCandlesAndAccessories,
                    defaults: ["None"]
                )
                choiceRow(
                    "Packaging",
                    field: .packaging,
                    value: $viewModel.draftCakePackaging,
                    defaults: ["Standard Box", "Tall Box", "Window Box"]
                )
            }
        }
    }

    private func choiceRow(
        _ label: String,
        field: OrderCakeRequirementField,
        value: Binding<String>,
        defaults: [String]
    ) -> some View {
        OrderCakeChoiceRow(
            label: label,
            identifier: "orders.form.cakeSpecification.\(field.rawValue)",
            value: value,
            choices: viewModel.cakeRequirementChoices(
                for: field,
                defaults: defaults,
                current: value.wrappedValue
            )
        )
    }

    private func suggestionTextField(
        _ label: String,
        field: OrderCakeRequirementField,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 8) {
            TextField(label, text: text)
            let choices = viewModel.cakeRequirementChoices(
                for: field,
                defaults: [],
                current: text.wrappedValue
            )
            if !choices.isEmpty {
                Menu {
                    ForEach(choices, id: \.self) { choice in
                        Button {
                            text.wrappedValue = choice
                        } label: {
                            if text.wrappedValue == choice {
                                Label(choice, systemImage: "checkmark")
                            } else {
                                Text(choice)
                            }
                        }
                        .accessibilityIdentifier("orders.form.cakeSpecification.previous.\(field.rawValue).\(choice)")
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous \(label) choices")
                .accessibilityValue(text.wrappedValue)
                .accessibilityIdentifier("orders.form.cakeSpecification.previous.\(field.rawValue)")
            }
        }
    }

    private func suggestionButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.footnote)
            .foregroundStyle(Color.cloudBakePink)
    }
}

private struct OrderCakeChoiceRow: View {
    let label: String
    let identifier: String
    @Binding var value: String
    let choices: [String]
    @State private var isEnteringCustomValue = false
    @State private var customValue = ""

    var body: some View {
        LabeledContent(label) {
            Menu {
                Button {
                    value = ""
                } label: {
                    if value.isEmpty {
                        Label("Not Set", systemImage: "checkmark")
                    } else {
                        Text("Not Set")
                    }
                }
                .accessibilityIdentifier("\(identifier).notSet")

                ForEach(choices, id: \.self) { choice in
                    Button {
                        value = choice
                    } label: {
                        if value == choice {
                            Label(choice, systemImage: "checkmark")
                        } else {
                            Text(choice)
                        }
                    }
                    .accessibilityIdentifier("\(identifier).choice.\(choice)")
                }

                Button("Other…") {
                    customValue = choices.contains(value) ? "" : value
                    Task { @MainActor in
                        await Task.yield()
                        isEnteringCustomValue = true
                    }
                }
                .accessibilityIdentifier("\(identifier).other")
            } label: {
                HStack(spacing: 5) {
                    Text(value.isEmpty ? "Not Set" : value)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(label)
            .accessibilityValue(value.isEmpty ? "Not Set" : value)
            .accessibilityIdentifier(identifier)
        }
        .cloudBakeInputPopup(
            isPresented: $isEnteringCustomValue,
            title: "Other \(label)",
            primaryTitle: "Use",
            primaryAccessibilityIdentifier: "\(identifier).other.use",
            cancelAccessibilityIdentifier: "\(identifier).other.cancel",
            onCancel: {
                isEnteringCustomValue = false
            },
            onSubmit: {
                let trimmed = customValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    value = trimmed
                    isEnteringCustomValue = false
                }
            }
        ) {
            TextField(label, text: $customValue)
        }
    }

}
