import SwiftUI

struct AppIntroductionPage: Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String

    static let all: [AppIntroductionPage] = [
        .init(id: "home", title: "Your bakery at a glance", detail: "See upcoming orders, reminders, and stock that needs attention from Home.", systemImage: "house"),
        .init(id: "orders", title: "Keep every order on track", detail: "Plan due dates, pricing, payments, recipes, designs, and preparation from one order.", systemImage: "calendar"),
        .init(id: "inventory", title: "Know what is available", detail: "Track batches, costs, expiry dates, shortages, and ingredient use without guesswork.", systemImage: "shippingbox"),
        .init(id: "library", title: "Build your bakery library", detail: "Keep recipes, cake designs, references, and customer preferences ready to reuse.", systemImage: "books.vertical"),
        .init(id: "backup", title: "Protect your bakery records", detail: "Use Cloud Backup for disaster recovery and create a full file backup whenever you need one.", systemImage: "icloud.and.arrow.up")
    ]
}

enum AppIntroductionPolicy {
    static func shouldPresent(
        hasCompleted: Bool,
        hasExistingOwnerData: Bool,
        isAutomatedTest: Bool,
        forcesPresentation: Bool
    ) -> Bool {
        forcesPresentation || (!hasCompleted && !hasExistingOwnerData && !isAutomatedTest)
    }
}

struct AppIntroductionView: View {
    let onFinish: () -> Void
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            CloudBakeScreenBackground()
            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .foregroundStyle(Color.cloudBakePink)
                        .accessibilityIdentifier("introduction.skip")
                }
                .padding(.horizontal, 24)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(AppIntroductionPage.all.enumerated()), id: \.element.id) { index, page in
                        VStack(spacing: 24) {
                            Image(systemName: page.systemImage)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(Color.cloudBakePink)
                                .frame(width: 132, height: 132)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                            Text(page.title)
                                .font(CloudBakeTheme.Typography.screenTitle)
                                .multilineTextAlignment(.center)
                            Text(page.detail)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 34)
                        .tag(index)
                        .accessibilityIdentifier("introduction.page.\(page.id)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(selectedIndex == AppIntroductionPage.all.count - 1 ? "Get Started" : "Next") {
                    if selectedIndex == AppIntroductionPage.all.count - 1 {
                        onFinish()
                    } else {
                        withAnimation { selectedIndex += 1 }
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.cloudBakePink, in: Capsule())
                .padding(.horizontal, 24)
                .accessibilityIdentifier(selectedIndex == AppIntroductionPage.all.count - 1 ? "introduction.getStarted" : "introduction.next")
            }
            .padding(.vertical, 20)
        }
        .accessibilityIdentifier("screen.introduction")
    }
}

struct HelpGuideView: View {
    @Environment(\.dismiss) private var dismiss
    let onShowIntroduction: () -> Void

    private let topics: [HelpTopic] = [
        HelpTopic(title: "Home", systemImage: "house", summary: "Review what needs attention today.", steps: [
            "Open an upcoming order to continue its preparation.",
            "Open a reminder or stock warning to address it at the source."
        ]),
        HelpTopic(title: "Orders", systemImage: "calendar", summary: "Plan and complete a customer order.", steps: [
            "Tap +, choose the customer and due date, then add pricing and payment details.",
            "Link recipes and designs, adjust ingredients as work changes, and update the status through Completed."
        ]),
        HelpTopic(title: "Inventory", systemImage: "shippingbox", summary: "Keep ingredient quantities and costs current.", steps: [
            "Tap + to add an item, or use the menu to import a bill, CSV file, or voice draft.",
            "Open an item to add a purchase batch; swipe a card for history, archive, or delete actions."
        ]),
        HelpTopic(title: "Recipes", systemImage: "book", summary: "Save reusable ingredient quantities.", steps: [
            "Tap + beside Recipes, name the recipe, and add each ingredient and quantity.",
            "Link the recipe from an order so CloudBake can estimate cost and required stock."
        ]),
        HelpTopic(title: "Designs & References", systemImage: "photo.on.rectangle", summary: "Keep cake ideas easy to find and reuse.", steps: [
            "Import a photo into Designs or add an order reference to the design library.",
            "Edit tags for searching, then choose the design from an order to link it."
        ]),
        HelpTopic(title: "Customers", systemImage: "person.2", summary: "Keep customer context with their orders.", steps: [
            "Add contact details, preferences, allergies, and notes to the customer.",
            "Use the customer ribbon to call, open WhatsApp, or create a new order."
        ]),
        HelpTopic(title: "Backup & Restore", systemImage: "icloud", summary: "Protect the complete app state.", steps: [
            "Expand Backup in Settings to run Cloud Backup or create a full file backup.",
            "Use Restore only when replacing local data, then review and confirm before proceeding."
        ])
    ]

    var body: some View {
        CloudBakeDetailScaffold(title: "Help & Guide", backAccessibilityIdentifier: "help.back", onBack: { dismiss() }) {
            CloudBakeSection("Getting Started") {
                CloudBakeDetailCard {
                    Button(action: onShowIntroduction) {
                        CloudBakeDetailRow("View Introduction") {
                            Image(systemName: "chevron.right").foregroundStyle(Color.cloudBakePink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help.viewIntroduction")
                }
            }
            CloudBakeSection("How to use CloudBake") {
                ForEach(topics) { topic in
                    CloudBakeDetailCard {
                        HStack(alignment: .top, spacing: 16) {
                            CloudBakeRowIcon(systemImage: topic.systemImage, tint: .cloudBakePink)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(topic.title).font(CloudBakeTheme.Typography.rowTitle)
                                Text(topic.summary).font(.footnote).foregroundStyle(.secondary)
                                ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                                    Text("\(index + 1). \(step)")
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }.padding(.vertical, 12)
                    }
                }
            }
        }
        .accessibilityIdentifier("screen.helpGuide")
    }
}

private struct HelpTopic: Identifiable {
    let title: String
    let systemImage: String
    let summary: String
    let steps: [String]

    var id: String { title }
}
