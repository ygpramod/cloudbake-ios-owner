import SwiftUI

struct PlaceholderScreen: View {
    let destination: AppDestination

    var body: some View {
        ContentUnavailableView(
            destination.title,
            systemImage: destination.systemImage,
            description: Text("This area will be implemented in a future RFC slice.")
        )
        .navigationTitle(destination.title)
        .accessibilityIdentifier(destination.screenAccessibilityIdentifier)
    }
}

#Preview("Orders") {
    PlaceholderScreen(destination: .orders)
}
