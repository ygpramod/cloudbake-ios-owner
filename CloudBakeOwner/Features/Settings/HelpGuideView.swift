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
    static func shouldPresent(hasCompleted: Bool, isAutomatedTest: Bool, forcesPresentation: Bool) -> Bool {
        forcesPresentation || (!hasCompleted && !isAutomatedTest)
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
    @State private var isShowingIntroduction = false

    private let topics: [(String, String, String)] = [
        ("Home", "house", "Review upcoming orders, reminders, and inventory warnings."),
        ("Orders", "calendar", "Create quotes, link customers, recipes and designs, record payments, and complete preparation."),
        ("Inventory", "shippingbox", "Add purchases, use or adjust stock, manage expiry, aliases, archived items, CSV files, and voice drafts."),
        ("Recipes", "book", "Save ingredients and quantities, import scans or CSV files, and link recipes to orders."),
        ("Designs & References", "photo.on.rectangle", "Import searchable cake photos, edit tags, and link the right reference to an order."),
        ("Customers", "person.2", "Keep contact details, preferences, allergies, references, and order history together."),
        ("Backup & Restore", "icloud", "Run Cloud Backup for disaster recovery, create full file backups, and confirm a restore before replacing local data.")
    ]

    var body: some View {
        CloudBakeDetailScaffold(title: "Help & Guide", backAccessibilityIdentifier: "help.back", onBack: { dismiss() }) {
            CloudBakeSection("Getting Started") {
                CloudBakeDetailCard {
                    Button { isShowingIntroduction = true } label: {
                        CloudBakeDetailRow("View Introduction") {
                            Image(systemName: "chevron.right").foregroundStyle(Color.cloudBakePink)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("help.viewIntroduction")
                }
            }
            CloudBakeSection("How to use CloudBake") {
                ForEach(Array(topics.enumerated()), id: \.offset) { _, topic in
                    CloudBakeDetailCard {
                        HStack(alignment: .top, spacing: 16) {
                            CloudBakeRowIcon(systemImage: topic.1, tint: .cloudBakePink)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(topic.0).font(CloudBakeTheme.Typography.rowTitle)
                                Text(topic.2).font(.footnote).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 12)
                    }
                }
            }
        }
        .accessibilityIdentifier("screen.helpGuide")
        .fullScreenCover(isPresented: $isShowingIntroduction) {
            AppIntroductionView { isShowingIntroduction = false }
        }
    }
}
