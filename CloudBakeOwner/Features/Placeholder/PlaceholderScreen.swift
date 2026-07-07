import SwiftUI

struct PlaceholderScreen: View {
    let destination: AppDestination

    var body: some View {
        CloudBakeScreenScaffold(
            title: destination.title,
            selectedDestination: destination
        ) {
            CloudBakeEmptyState(
                title: destination.title,
                systemImage: destination.systemImage,
                message: "This area will be implemented in a future RFC slice."
            )
        }
        .accessibilityIdentifier(destination.screenAccessibilityIdentifier)
    }
}

#Preview("Orders") {
    PlaceholderScreen(destination: .orders)
}
