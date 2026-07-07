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
        Section("Checklist") {
            if items.isEmpty {
                Text("No checklist items")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("orders.detail.checklist.empty")
            } else {
                ForEach(items, id: \.id) { item in
                    checklistRow(for: item)
                }
            }

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
        }
    }

    private func checklistRow(for item: OrderChecklistItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isCompleted ? .green : .secondary)
            Text(item.title)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(item)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("orders.detail.checklist.item.\(item.id)")
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isCompleted ? "Complete" : "Incomplete")
        .accessibilityAction {
            onToggle(item)
        }
        .swipeActions(edge: .trailing) {
            Button {
                onEdit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            .accessibilityIdentifier("orders.detail.checklist.edit.\(item.id)")

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("orders.detail.checklist.delete.\(item.id)")
        }
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
