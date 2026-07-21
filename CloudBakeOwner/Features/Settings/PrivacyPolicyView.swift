import SwiftUI

struct PrivacyPolicySection: Equatable, Identifiable {
    let id: String
    let title: String
    let paragraphs: [String]
}

enum PrivacyPolicyContent {
    static let effectiveDate = "21 July 2026"
    static let onlinePolicyURL = URL(
        string: "https://github.com/ygpramod/cloudbake-ios-owner/blob/main/wiki/Privacy-Policy.md"
    )

    static let sections: [PrivacyPolicySection] = [
        .init(
            id: "stored-data",
            title: "Data CloudBake Stores",
            paragraphs: [
                "CloudBake stores the bakery information you enter, including inventory, recipes, designs, photos, customers, orders, pricing, payments, reminders, and app preferences.",
                "This information is stored locally in CloudBake's private app storage on your iPhone. CloudBake does not include advertising, analytics, or tracking SDKs."
            ]
        ),
        .init(
            id: "cloud-backup",
            title: "Cloud Backup",
            paragraphs: [
                "When Cloud Backup is enabled, CloudBake stores one complete recovery backup in the private CloudKit database belonging to the iCloud account signed in on the iPhone.",
                "Apple states that private CloudKit data is accessible only to the current user by default and is not visible in the developer portal. You can disable Cloud Backup or delete its stored backup from Settings."
            ]
        ),
        .init(
            id: "device-access",
            title: "Device Access",
            paragraphs: [
                "CloudBake accesses photos, the camera, contacts, the microphone, speech recognition, and notifications only for features you choose to use and after iOS permission is granted.",
                "Voice inventory recognition is processed on the device. CloudBake does not retain microphone audio. Imported photos are copied into app-managed storage; original Photos-library items remain under your control."
            ]
        ),
        .init(
            id: "retention",
            title: "Retention and Deletion",
            paragraphs: [
                "Local records remain until you delete them or remove the app. Manual backup files remain wherever you chose to export them.",
                "Deleting CloudBake does not delete original photos in the Photos library or manually exported backup files. Delete the Cloud Backup from Settings before removing the app if you also want its recovery copy removed from iCloud."
            ]
        ),
        .init(
            id: "sharing",
            title: "Sharing and Contact",
            paragraphs: [
                "CloudBake does not sell personal information and does not share bakery data with advertisers or data brokers.",
                "For privacy questions, use the CloudBake support repository. Do not include customer details, recipes, photos, or other private bakery information in a public support request."
            ]
        )
    ]
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CloudBakeDetailScaffold(
            title: "Privacy",
            backAccessibilityIdentifier: "privacy.back",
            onBack: { dismiss() }
        ) {
            CloudBakeSection("Privacy Policy") {
                CloudBakeDetailCard {
                    Text("Effective \(PrivacyPolicyContent.effectiveDate)")
                        .font(.subheadline.weight(.semibold))
                    Text("CloudBake is a private, local-first bakery management app. This policy explains where your information is stored and the controls available to you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(PrivacyPolicyContent.sections) { section in
                CloudBakeSection(section.title) {
                    CloudBakeDetailCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }

            if let onlinePolicyURL = PrivacyPolicyContent.onlinePolicyURL {
                CloudBakeSection("Online Copy") {
                    CloudBakeDetailCard {
                        Link(destination: onlinePolicyURL) {
                            CloudBakeDetailRow("View Online Privacy Policy") {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Color.cloudBakePink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("privacy.onlinePolicy")
                    }
                }
            }
        }
        .accessibilityIdentifier("screen.privacyPolicy")
    }
}
