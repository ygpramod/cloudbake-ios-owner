import SwiftUI

struct OrderDetailChecklistSection: View {
    @Binding var draftTitle: String
    let items: [OrderChecklistItem]
    let isTitleFocused: FocusState<Bool>.Binding
    let onAdd: () -> Bool
    let onToggle: (OrderChecklistItem) -> Void
    let onEdit: (OrderChecklistItem) -> Void
    let onDelete: (OrderChecklistItem) -> Void

    var body: some View {
        CloudBakeSection("Checklist") {
            CloudBakeDetailCard {
            if items.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cloudBakePink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.cloudBakePink.opacity(0.10)))
                    Text("No checklist items")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("orders.detail.checklist.empty")
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                ForEach(items, id: \.id) { item in
                    checklistRow(for: item)
                    if item.id != items.last?.id {
                        CloudBakeDetailDivider()
                    }
                }
            }

            CloudBakeDetailDivider()

            HStack {
                TextField("Add checklist item", text: $draftTitle)
                    .textInputAutocapitalization(.sentences)
                    .focused(isTitleFocused)
                    .accessibilityIdentifier("orders.detail.checklist.title")

                Button {
                    if onAdd() {
                        isTitleFocused.wrappedValue = false
                    }
                } label: {
                    Label("Add Checklist Item", systemImage: "plus.circle")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("orders.detail.checklist.add")
            }
            .padding(.vertical, 12)
            }
        }
    }

    private func checklistRow(for item: OrderChecklistItem) -> some View {
        HStack(spacing: 10) {
            Button {
                onToggle(item)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("orders.detail.checklist.item.\(item.id)")
            .accessibilityLabel(item.title)
            .accessibilityValue(item.isCompleted ? "Complete" : "Incomplete")
            Button {
                onEdit(item)
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.cloudBakePink)
            .accessibilityLabel("Edit \(item.title)")
            .accessibilityIdentifier("orders.detail.checklist.edit.\(item.id)")

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("Delete \(item.title)")
            .accessibilityIdentifier("orders.detail.checklist.delete.\(item.id)")
        }
        .padding(.vertical, 12)
    }
}

struct OrderChecklistEditForm: View {
    @Binding var title: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("Checklist Item") {
                TextField("Title", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("orders.detail.checklist.edit.title")
            }
        }
        .navigationTitle("Edit Checklist Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
                    .accessibilityIdentifier("orders.detail.checklist.edit.cancel")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
                    .accessibilityIdentifier("orders.detail.checklist.edit.save")
            }
        }
    }
}
