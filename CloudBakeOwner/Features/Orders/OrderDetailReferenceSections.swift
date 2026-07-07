import SwiftUI

struct OrderDetailRecipeSection: View {
    let order: Order
    let recipe: Recipe?
    let recipeUsage: OrderRecipeUsage?

    var body: some View {
        if order.recipeId != nil {
            Section("Recipe") {
                LabeledContent("Linked Recipe") {
                    Text(recipe?.name ?? "Recipe unavailable")
                        .accessibilityIdentifier("orders.detail.recipeName")
                }
                LabeledContent("Recipe Multiplier") {
                    Text(TextInputFormatting.decimalText(order.recipeScaleMultiplier))
                        .accessibilityIdentifier("orders.detail.recipeScaleMultiplier")
                }
                LabeledContent("Usage") {
                    if let recipeUsage {
                        Text("\(recipeUsage.usedAt.formatted(date: .abbreviated, time: .shortened)) at \(TextInputFormatting.decimalText(recipeUsage.recipeScaleMultiplier))x")
                            .accessibilityIdentifier("orders.detail.recipeUsage")
                    } else {
                        Text("When Ready")
                            .accessibilityIdentifier("orders.detail.recipeUsage")
                    }
                }
            }
        }
    }
}

struct OrderDetailDesignSection: View {
    let order: Order
    let cakeDesign: CakeDesign?

    var body: some View {
        if order.cakeDesignId != nil {
            Section("Design") {
                LabeledContent("Reference") {
                    Text(cakeDesign?.name ?? "Design unavailable")
                        .accessibilityIdentifier("orders.detail.designName")
                }

                if let notes = cakeDesign?.notes {
                    LabeledContent("Notes") {
                        Text(notes)
                            .accessibilityIdentifier("orders.detail.designNotes")
                    }
                }

                if let photoReference = cakeDesign?.photoReference {
                    LabeledContent("Photo") {
                        Text(photoReference)
                            .lineLimit(2)
                            .accessibilityIdentifier("orders.detail.designPhotoReference")
                    }
                }
            }
        }
    }
}

struct OrderDetailFulfillmentSection: View {
    let order: Order

    var body: some View {
        Section("Fulfillment") {
            LabeledContent("Type") {
                Text(order.fulfillmentType.displayName)
                    .accessibilityIdentifier("orders.detail.fulfillmentType")
            }
            if let deliveryAddress = order.deliveryAddress {
                LabeledContent("Address", value: deliveryAddress)
            }
        }
    }
}

struct OrderDetailCakeNotesSection: View {
    let order: Order

    var body: some View {
        if let cakeNotes = order.cakeNotes {
            Section("Cake Notes") {
                Text(cakeNotes)
                    .accessibilityIdentifier("orders.detail.cakeNotes")
            }
        }
    }
}
